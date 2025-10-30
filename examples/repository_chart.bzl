"""Example demonstrating Helm repository chart deployment.

This example shows how to use helm_repository and helm_release macros to deploy
charts from Helm repositories with full support for authentication and
version management.
"""

load("@helm_tools//:defs.bzl", "helm_repository", "helm_release")

def example_repository_charts():
    """Examples of using repository charts with helm_release."""

    # Define repositories for HTTP/HTTPS URLs
    helm_repository(
        name = "bitnami",
        url = "https://charts.bitnami.com/bitnami",
    )

    helm_repository(
        name = "grafana",
        url = "https://grafana.github.io/helm-charts",
    )

    helm_repository(
        name = "prometheus_community",
        url = "https://prometheus-community.github.io/helm-charts",
    )

    # Example 1: Public repository chart
    helm_release(
        name = "nginx",
        chart = "nginx",
        repo_name = ":bitnami",  # Reference the repository
        chart_version = "13.2.10",
        namespace = "web",
        values_file = ":nginx-values.yaml",
        create_namespace = True,
        wait = True,
        timeout = "5m",
    )

    # Example 2: Chart with specific version from another repository
    helm_release(
        name = "grafana",
        chart = "grafana",
        repo_name = ":grafana",  # Reference the repository
        chart_version = "6.59.0",
        namespace = "monitoring",
        values_file = ":grafana-values.yaml",
        create_namespace = True,
        atomic = True,  # Rollback on failure
    )

    # Example 3: OCI registry chart (can use repo_url directly)
    helm_release(
        name = "oci_chart",
        chart = "my-chart",
        repo_url = "oci://registry.example.com/charts",  # OCI URLs work directly
        chart_version = "2.0.0",
        namespace = "staging",
        wait = True,
    )

    # Example 4: Using latest version (no version specified)
    helm_release(
        name = "prometheus",
        chart = "kube-prometheus-stack",
        repo_name = ":prometheus_community",  # Reference the repository
        namespace = "monitoring",
        create_namespace = True,
        wait = True,
        timeout = "10m",
    )

    # Example 5: Private repository with authentication
    helm_repository(
        name = "private_repo",
        url = "https://charts.company.com",
        username = "myuser",
        password = "mypass",
        ca_file = ":ca-bundle.pem",  # Optional CA certificate
    )

    helm_release(
        name = "private_app",
        chart = "internal-app",
        repo_name = ":private_repo",
        chart_version = "3.2.1",
        namespace = "internal",
        create_namespace = True,
        atomic = True,
    )

    # Example 6: File-based repository (can use repo_url directly)
    helm_release(
        name = "local_repo_chart",
        chart = "local-chart",
        repo_url = "file:///path/to/local/repo",  # File URLs work directly
        chart_version = "0.1.0",
        namespace = "dev",
    )
