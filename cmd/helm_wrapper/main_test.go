package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestBuildCommand(t *testing.T) {
	tests := []struct {
		name       string
		config     Config
		wantArgs   []string
		wantErr    bool
	}{
		{
			name: "repository add",
			config: Config{
				Type:     "repository",
				RepoName: "jetstack",
				URL:      "https://charts.jetstack.io",
			},
			wantArgs: []string{"repo", "add", "jetstack", "https://charts.jetstack.io"},
		},
		{
			name: "repository add with auth",
			config: Config{
				Type:        "repository",
				RepoName:    "private",
				URL:         "https://charts.example.com",
				Username:    "user",
				Password:    "pass",
				ForceUpdate: true,
			},
			wantArgs: []string{"repo", "add", "private", "https://charts.example.com", "--username", "user", "--password", "pass", "--force-update"},
		},
		{
			name: "install with repository",
			config: Config{
				Type:        "release",
				Command:     "install",
				ReleaseName: "cert-manager",
				Chart:       "cert-manager",
				Repository:  "jetstack",
				Namespace:   "cert-manager",
				Version:     "v1.13.2",
				Flags:       []string{"--create-namespace", "--wait"},
			},
			wantArgs: []string{"upgrade", "--install", "cert-manager", "jetstack/cert-manager", "--namespace", "cert-manager", "--version", "v1.13.2", "--create-namespace", "--wait"},
		},
		{
			name: "install with repo URL",
			config: Config{
				Type:        "release",
				Command:     "install",
				ReleaseName: "prometheus",
				Chart:       "kube-prometheus-stack",
				RepoURL:     "https://prometheus-community.github.io/helm-charts",
				Namespace:   "monitoring",
			},
			wantArgs: []string{"upgrade", "--install", "prometheus", "kube-prometheus-stack", "--repo", "https://prometheus-community.github.io/helm-charts", "--namespace", "monitoring"},
		},
		{
			name: "upgrade with repository",
			config: Config{
				Type:        "release",
				Command:     "upgrade",
				ReleaseName: "cert-manager",
				Chart:       "cert-manager",
				Repository:  "jetstack",
				Namespace:   "cert-manager",
				Version:     "v1.13.3",
				Timeout:     "10m",
			},
			wantArgs: []string{"upgrade", "cert-manager", "jetstack/cert-manager", "--namespace", "cert-manager", "--version", "v1.13.3", "--timeout", "10m"},
		},
		{
			name: "uninstall",
			config: Config{
				Type:        "release",
				Command:     "uninstall",
				ReleaseName: "cert-manager",
				Namespace:   "cert-manager",
			},
			wantArgs: []string{"uninstall", "cert-manager", "--namespace", "cert-manager"},
		},
		{
			name: "status",
			config: Config{
				Type:        "release",
				Command:     "status",
				ReleaseName: "cert-manager",
				Namespace:   "cert-manager",
			},
			wantArgs: []string{"status", "cert-manager", "--namespace", "cert-manager"},
		},
		{
			name: "get values",
			config: Config{
				Type:        "release",
				Command:     "get",
				ReleaseName: "cert-manager",
				Namespace:   "cert-manager",
			},
			wantArgs: []string{"get", "values", "cert-manager", "--namespace", "cert-manager"},
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cmd, err := buildCommand("helm", &tt.config, false)
			if (err != nil) != tt.wantErr {
				t.Errorf("buildCommand() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			
			if err == nil {
				gotArgs := cmd.Args[1:] // Skip the binary name
				if !equalStringSlices(gotArgs, tt.wantArgs) {
					t.Errorf("buildCommand() args = %v, want %v", gotArgs, tt.wantArgs)
				}
			}
		})
	}
}

func TestLoadConfig(t *testing.T) {
	// Create a temporary config file
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.json")
	
	config := Config{
		Type:        "release",
		Command:     "install",
		ReleaseName: "test",
		Chart:       "test-chart",
		Repository:  "test-repo",
		Namespace:   "test-ns",
		Version:     "1.0.0",
		Flags:       []string{"--wait"},
	}
	
	data, err := json.Marshal(config)
	if err != nil {
		t.Fatalf("Failed to marshal config: %v", err)
	}
	
	if err := os.WriteFile(configFile, data, 0644); err != nil {
		t.Fatalf("Failed to write config file: %v", err)
	}
	
	// Test loading the config
	loaded, err := loadConfig(configFile)
	if err != nil {
		t.Fatalf("loadConfig() error = %v", err)
	}
	
	if loaded.Type != config.Type {
		t.Errorf("Type = %v, want %v", loaded.Type, config.Type)
	}
	if loaded.Command != config.Command {
		t.Errorf("Command = %v, want %v", loaded.Command, config.Command)
	}
	if loaded.ReleaseName != config.ReleaseName {
		t.Errorf("ReleaseName = %v, want %v", loaded.ReleaseName, config.ReleaseName)
	}
	if loaded.Chart != config.Chart {
		t.Errorf("Chart = %v, want %v", loaded.Chart, config.Chart)
	}
	if loaded.Repository != config.Repository {
		t.Errorf("Repository = %v, want %v", loaded.Repository, config.Repository)
	}
}

func equalStringSlices(a, b []string) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}

func TestVerboseFlag(t *testing.T) {
	config := Config{
		Type:        "release",
		Command:     "install",
		ReleaseName: "test",
		Chart:       "test-chart",
		Namespace:   "default",
	}
	
	cmd, err := buildCommand("helm", &config, true)
	if err != nil {
		t.Fatalf("buildCommand() error = %v", err)
	}
	
	// Check that --debug flag is added when verbose is true
	args := strings.Join(cmd.Args[1:], " ")
	if !strings.Contains(args, "--debug") {
		t.Errorf("Expected --debug flag when verbose=true, got: %s", args)
	}
}