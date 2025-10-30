package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strings"

	"gopkg.in/yaml.v3"
)

// Config represents the configuration for helm operations
type Config struct {
	Type        string   `json:"type"`    // "repository" or "release"
	Command     string   `json:"command"` // install, upgrade, uninstall, status, get
	ReleaseName string   `json:"release_name"`
	Chart       string   `json:"chart"`
	Repository  string   `json:"repository,omitempty"` // Repository name (from helm_repository)
	RepoURL     string   `json:"repo_url,omitempty"`   // Direct repository URL
	RepoName    string   `json:"repo_name,omitempty"`  // For repository add command
	Namespace   string   `json:"namespace,omitempty"`
	Version     string   `json:"version,omitempty"`
	ValuesFile  string   `json:"values_file,omitempty"`
	Flags       []string `json:"flags,omitempty"`
	Timeout     string   `json:"timeout,omitempty"`

	// Repository-specific fields
	URL                   string `json:"url,omitempty"`
	CAFile                string `json:"ca_file,omitempty"`
	CertFile              string `json:"cert_file,omitempty"`
	Username              string `json:"username,omitempty"`
	Password              string `json:"password,omitempty"`
	ForceUpdate           bool   `json:"force_update,omitempty"`
	InsecureSkipTLSVerify bool   `json:"insecure_skip_tls_verify,omitempty"`
	NoUpdate              bool   `json:"no_update,omitempty"`
}

func main() {
	var configFile string
	var helmBinary string
	var verbose bool
	var repoConfigFile string
	var valuesFile string

	// Custom flag handling to support pass-through arguments
	args := os.Args[1:]
	passThrough := []string{}

	i := 0
	for i < len(args) {
		arg := args[i]
		if arg == "--" {
			// Everything after -- should be passed to helm
			if i+1 < len(args) {
				passThrough = args[i+1:]
			}
			args = args[:i]
			break
		}
		i++
	}

	// Set os.Args for flag.Parse()
	os.Args = append([]string{os.Args[0]}, args...)

	var chartPath string
	flag.StringVar(&configFile, "config", "", "Path to configuration JSON file")
	flag.StringVar(&helmBinary, "helm", "helm", "Path to helm binary")
	flag.BoolVar(&verbose, "verbose", false, "Enable verbose output")
	flag.StringVar(&repoConfigFile, "repo-config", "", "Path to repository configuration JSON (for releases using repo_name)")
	flag.StringVar(&valuesFile, "values", "", "Path to values file (overrides config)")
	flag.StringVar(&chartPath, "chart", "", "Path to chart (overrides config, for Bazel label expansion)")
	flag.Parse()

	// Additional arguments to pass to helm
	additionalArgs := append(flag.Args(), passThrough...)

	if configFile == "" {
		log.Fatal("--config flag is required")
	}

	// Load configuration
	config, err := loadConfig(configFile)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// If repo config is provided, load repository details and add the repository
	if repoConfigFile != "" {
		repoConfig, err := loadConfig(repoConfigFile)
		if err != nil {
			log.Fatalf("Failed to load repository config: %v", err)
		}
		if repoConfig.RepoName != "" {
			config.Repository = repoConfig.RepoName

			// Add the repository before running the main command
			if verbose {
				fmt.Fprintf(os.Stderr, "Adding repository %s from %s\n", repoConfig.RepoName, repoConfig.URL)
			}

			// Build helm repo add command
			repoCmd, err := buildCommand(helmBinary, repoConfig, verbose)
			if err != nil {
				log.Fatalf("Failed to build repo add command: %v", err)
			}

			// Execute helm repo add
			repoCmd.Stdout = os.Stdout
			repoCmd.Stderr = os.Stderr
			if err := repoCmd.Run(); err != nil {
				// Don't fail if repo already exists
				if verbose {
					fmt.Fprintf(os.Stderr, "Warning: Failed to add repository (may already exist): %v\n", err)
				}
			}
		}
	}

	// Override values file if provided via flag
	if valuesFile != "" {
		config.ValuesFile = valuesFile
	}

	// Override chart path if provided via flag (for Bazel label expansion)
	if chartPath != "" && config.Chart == "__CHART_PATH__" {
		config.Chart = chartPath
	}

	// For install/upgrade commands with local charts, check if dependencies need to be built
	if (config.Command == "install" || config.Command == "upgrade") &&
		config.Repository == "" && config.RepoURL == "" {
		// This is a local chart - check if it needs dependency building
		// Check if chart is a .tar.gz archive
		if len(config.Chart) > 7 && config.Chart[len(config.Chart)-7:] == ".tar.gz" {
			// Extract archive to temporary directory
			tmpDir, err := os.MkdirTemp("", "helm-chart-*")
			if err != nil {
				log.Fatalf("Failed to create temp directory: %v", err)
			}
			defer os.RemoveAll(tmpDir)
			if verbose {
				fmt.Fprintf(os.Stderr, "Extracting chart archive %s to %s\n", config.Chart, tmpDir)
			}

			// Extract the tarball
			tarCmd := exec.Command("tar", "-xzf", config.Chart, "-C", tmpDir)
			tarCmd.Stderr = os.Stderr
			if err := tarCmd.Run(); err != nil {
				log.Fatalf("Failed to extract chart archive: %v", err)
			}

			// Update chart path to extracted directory
			config.Chart = tmpDir

			// Check if it needs dependency building
			if needsDependencyBuild(config.Chart, verbose) {
				if verbose {
					fmt.Fprintf(os.Stderr, "Building chart dependencies for %s\n", config.Chart)
				}

				// Add required repositories before building dependencies
				if err := addDependencyRepositories(helmBinary, config.Chart, verbose); err != nil {
					log.Fatalf("Failed to add dependency repositories: %v", err)
				}

				depCmd := exec.Command(helmBinary, "dependency", "build", config.Chart)
				depCmd.Stdout = os.Stdout
				depCmd.Stderr = os.Stderr
				if err := depCmd.Run(); err != nil {
					log.Fatalf("Failed to build chart dependencies: %v", err)
				}
			}
		} else {
			// This is a local chart directory - check if it needs dependency building
			if needsDependencyBuild(config.Chart, verbose) {
				if verbose {
					fmt.Fprintf(os.Stderr, "Building chart dependencies for %s\n", config.Chart)
				}

				// Add required repositories before building dependencies
				if err := addDependencyRepositories(helmBinary, config.Chart, verbose); err != nil {
					log.Fatalf("Failed to add dependency repositories: %v", err)
				}

				depCmd := exec.Command(helmBinary, "dependency", "build", config.Chart)
				depCmd.Stdout = os.Stdout
				depCmd.Stderr = os.Stderr
				if err := depCmd.Run(); err != nil {
					log.Fatalf("Failed to build chart dependencies: %v", err)
				}
			}
		}
	}

	// Build and execute command
	cmd, err := buildCommand(helmBinary, config, verbose)
	if err != nil {
		log.Fatalf("Failed to build command: %v", err)
	}

	// Append additional arguments passed from command line
	cmd.Args = append(cmd.Args, additionalArgs...)

	if verbose {
		fmt.Fprintf(os.Stderr, "Executing: %s %v\n", cmd.Path, cmd.Args[1:])
	}

	// Execute the command
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			os.Exit(exitErr.ExitCode())
		}
		log.Fatalf("Failed to execute helm command: %v", err)
	}
}

func loadConfig(configFile string) (*Config, error) {
	data, err := os.ReadFile(configFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config JSON: %w", err)
	}

	return &config, nil
}

func needsDependencyBuild(chartPath string, verbose bool) bool {
	// Check if Chart.yaml exists
	chartYamlPath := fmt.Sprintf("%s/Chart.yaml", chartPath)
	chartYamlData, err := os.ReadFile(chartYamlPath)
	if err != nil {
		// If we can't read Chart.yaml, assume no dependencies needed
		if verbose {
			fmt.Fprintf(os.Stderr, "Could not read Chart.yaml at %s: %v\n", chartYamlPath, err)
		}
		return false
	}

	// Simple check: if Chart.yaml contains "dependencies:" then we might need to build
	if !contains(string(chartYamlData), "dependencies:") {
		return false
	}

	// Check if charts/ directory exists and has .tgz files
	chartsDir := fmt.Sprintf("%s/charts", chartPath)
	entries, err := os.ReadDir(chartsDir)
	if err != nil {
		// charts/ directory doesn't exist or can't be read - needs building
		return true
	}

	// Check if there are any .tgz files in charts/
	hasTgz := false
	for _, entry := range entries {
		if !entry.IsDir() && (len(entry.Name()) > 4 && entry.Name()[len(entry.Name())-4:] == ".tgz") {
			hasTgz = true
			break
		}
	}

	// If we have dependencies declared but no .tgz files, we need to build
	return !hasTgz
}

func contains(s, substr string) bool {
	return strings.Contains(s, substr)
}

type ChartYaml struct {
	Dependencies []struct {
		Name       string `yaml:"name"`
		Repository string `yaml:"repository"`
	} `yaml:"dependencies"`
}

func addDependencyRepositories(helmBinary, chartPath string, verbose bool) error {
	chartYamlPath := fmt.Sprintf("%s/Chart.yaml", chartPath)
	data, err := os.ReadFile(chartYamlPath)
	if err != nil {
		return fmt.Errorf("failed to read Chart.yaml: %w", err)
	}

	var chart ChartYaml
	if err := yaml.Unmarshal(data, &chart); err != nil {
		return fmt.Errorf("failed to parse Chart.yaml: %w", err)
	}

	repos := make(map[string]string) // URL -> name
	for _, dep := range chart.Dependencies {
		if strings.HasPrefix(dep.Repository, "http") {
			name := generateRepoName(dep.Repository)
			repos[dep.Repository] = name
		}
	}

	// Add repositories
	for url, name := range repos {
		if verbose {
			fmt.Fprintf(os.Stderr, "Adding repository %s (%s)\n", name, url)
		}
		cmd := exec.Command(helmBinary, "repo", "add", name, url)
		cmd.Stderr = os.Stderr
		_ = cmd.Run() // Ignore errors - repo might already exist
	}

	// Update repository index
	if len(repos) > 0 {
		if verbose {
			fmt.Fprintf(os.Stderr, "Updating repository index\n")
		}
		cmd := exec.Command(helmBinary, "repo", "update")
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("failed to update repos: %w", err)
		}
	}

	return nil
}

func generateRepoName(url string) string {
	// https://prometheus-community.github.io/helm-charts -> prometheus-community
	url = strings.TrimPrefix(url, "https://")
	url = strings.TrimPrefix(url, "http://")

	if idx := strings.Index(url, ".github.io"); idx > 0 {
		return url[:idx]
	}
	if idx := strings.Index(url, "/"); idx > 0 {
		return strings.ReplaceAll(url[:idx], ".", "-")
	}
	return strings.ReplaceAll(url, ".", "-")
}

func buildCommand(helmBinary string, config *Config, verbose bool) (*exec.Cmd, error) {
	args := []string{}

	// Handle different operation types
	switch config.Type {
	case "repository":
		// helm repo add <name> <url> [flags]
		args = append(args, "repo", "add", config.RepoName, config.URL)

		if config.CAFile != "" {
			args = append(args, "--ca-file", config.CAFile)
		}
		if config.CertFile != "" {
			args = append(args, "--cert-file", config.CertFile)
		}
		if config.Username != "" {
			args = append(args, "--username", config.Username)
		}
		if config.Password != "" {
			args = append(args, "--password", config.Password)
		}
		if config.ForceUpdate {
			args = append(args, "--force-update")
		}
		if config.InsecureSkipTLSVerify {
			args = append(args, "--insecure-skip-tls-verify")
		}
		if config.NoUpdate {
			args = append(args, "--no-update")
		}

	case "release":
		// Build helm command based on operation
		switch config.Command {
		case "install":
			// Use upgrade --install to make the command idempotent
			args = append(args, "upgrade", "--install", config.ReleaseName)

			// Add chart reference
			if config.Repository != "" {
				// Using repository name from helm_repository
				args = append(args, fmt.Sprintf("%s/%s", config.Repository, config.Chart))
			} else if config.RepoURL != "" {
				// Direct repository URL
				args = append(args, config.Chart, "--repo", config.RepoURL)
			} else {
				// Local chart or archive
				args = append(args, config.Chart)
			}

		case "upgrade":
			args = append(args, "upgrade", config.ReleaseName)

			// Add chart reference
			if config.Repository != "" {
				// Using repository name from helm_repository
				args = append(args, fmt.Sprintf("%s/%s", config.Repository, config.Chart))
			} else if config.RepoURL != "" {
				// Direct repository URL
				args = append(args, config.Chart, "--repo", config.RepoURL)
			} else {
				// Local chart or archive
				args = append(args, config.Chart)
			}

		case "uninstall":
			args = append(args, "uninstall", config.ReleaseName)

		case "status":
			args = append(args, "status", config.ReleaseName)

		case "get":
			args = append(args, "get", "values", config.ReleaseName)

		default:
			return nil, fmt.Errorf("unknown command: %s", config.Command)
		}

		// Add common flags for install/upgrade
		if config.Command == "install" || config.Command == "upgrade" {
			if config.Namespace != "" && config.Namespace != "default" {
				args = append(args, "--namespace", config.Namespace)
			}
			if config.Version != "" {
				args = append(args, "--version", config.Version)
			}
			if config.ValuesFile != "" {
				// Values file is already expanded by Bazel
				args = append(args, "--values", config.ValuesFile)
			}
			if config.Timeout != "" {
				args = append(args, "--timeout", config.Timeout)
			}
		} else if config.Namespace != "" && config.Namespace != "default" {
			// For uninstall, status, get commands
			args = append(args, "--namespace", config.Namespace)
		}

		// Add additional flags
		args = append(args, config.Flags...)

	default:
		return nil, fmt.Errorf("unknown config type: %s", config.Type)
	}

	if verbose {
		args = append(args, "--debug")
	}

	return exec.Command(helmBinary, args...), nil
}

