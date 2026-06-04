import subprocess
import time
import yaml
import os


def generate_pod_chaos(safe_name, namespace="chaos-testing"):
    return {
        "apiVersion": "chaos-mesh.org/v1alpha1",
        "kind": "PodChaos",
        "metadata": {
            "name": f"pod-chaos-{safe_name}",
            "namespace": namespace
        },
        "spec": {
            "action": "pod-kill",
            "mode": "one",
            "selector": {
                "namespaces": ["default"],
                "labelSelectors": {
                    "app": f"resilience-{safe_name}"
                }
            },
            "duration": "30s"
        }
    }


def generate_cpu_stress(safe_name, namespace="chaos-testing"):
    return {
        "apiVersion": "chaos-mesh.org/v1alpha1",
        "kind": "StressChaos",
        "metadata": {
            "name": f"cpu-stress-{safe_name}",
            "namespace": namespace
        },
        "spec": {
            "mode": "one",
            "selector": {
                "namespaces": ["default"],
                "labelSelectors": {
                    "app": f"resilience-{safe_name}"
                }
            },
            "stressors": {
                "cpu": {
                    "workers": 2,
                    "load": 80
                }
            },
            "duration": "60s"
        }
    }


def generate_memory_stress(safe_name, namespace="chaos-testing"):
    return {
        "apiVersion": "chaos-mesh.org/v1alpha1",
        "kind": "StressChaos",
        "metadata": {
            "name": f"memory-stress-{safe_name}",
            "namespace": namespace
        },
        "spec": {
            "mode": "one",
            "selector": {
                "namespaces": ["default"],
                "labelSelectors": {
                    "app": f"resilience-{safe_name}"
                }
            },
            "stressors": {
                "memory": {
                    "workers": 2,
                    "size": "256MB"
                }
            },
            "duration": "60s"
        }
    }


def generate_network_delay(safe_name, namespace="chaos-testing"):
    return {
        "apiVersion": "chaos-mesh.org/v1alpha1",
        "kind": "NetworkChaos",
        "metadata": {
            "name": f"network-delay-{safe_name}",
            "namespace": namespace
        },
        "spec": {
            "action": "delay",
            "mode": "all",
            "selector": {
                "namespaces": ["default"],
                "labelSelectors": {
                    "app": f"resilience-{safe_name}"
                }
            },
            "delay": {
                "latency": "3000ms",
                "correlation": "100",
                "jitter": "0ms"
            },
            "duration": "60s"
        }
    }


def generate_packet_loss(safe_name, namespace="chaos-testing"):
    return {
        "apiVersion": "chaos-mesh.org/v1alpha1",
        "kind": "NetworkChaos",
        "metadata": {
            "name": f"packet-loss-{safe_name}",
            "namespace": namespace
        },
        "spec": {
            "action": "loss",
            "mode": "one",
            "selector": {
                "namespaces": ["default"],
                "labelSelectors": {
                    "app": f"resilience-{safe_name}"
                }
            },
            "loss": {
                "loss": "30",
            },
            "duration": "60s"
        }
    }


def apply_chaos(chaos_dict, yaml_path):
    with open(yaml_path, "w") as f:
        yaml.dump(chaos_dict, f)
    result = subprocess.run(
        ["kubectl", "apply", "-f", yaml_path],
        capture_output=True, text=True
    )
    return result.returncode == 0


def delete_chaos(yaml_path):
    subprocess.run(
        ["kubectl", "delete", "-f", yaml_path, "--ignore-not-found=true"],
        capture_output=True
    )


def check_recovery(safe_name, required_pods=2):
    time.sleep(30)
    result = subprocess.run(
        [
            "kubectl", "get", "pods",
            "-l", f"app=resilience-{safe_name}",
            "--no-headers"
        ],
        capture_output=True, text=True
    )
    running = len([
        line for line in result.stdout.strip().split("\n")
        if line and "Running" in line
    ])
    return running >= required_pods


def run_all_chaos_tests(safe_name):
    results = {}

    tests = [
        {
            "name": "Pod Chaos Test",
            "key": "pod_chaos",
            "yaml_func": generate_pod_chaos,
            "path": f"/tmp/pod-chaos-{safe_name}.yaml"
        },
        {
            "name": "CPU Stress Test",
            "key": "cpu_stress",
            "yaml_func": generate_cpu_stress,
            "path": f"/tmp/cpu-stress-{safe_name}.yaml"
        },
        {
            "name": "Memory Stress Test",
            "key": "memory_stress",
            "yaml_func": generate_memory_stress,
            "path": f"/tmp/memory-stress-{safe_name}.yaml"
        },
        {
            "name": "Network Delay Test",
            "key": "network_delay",
            "yaml_func": generate_network_delay,
            "path": f"/tmp/network-delay-{safe_name}.yaml"
        },
        {
            "name": "Packet Loss Test",
            "key": "packet_loss",
            "yaml_func": generate_packet_loss,
            "path": f"/tmp/packet-loss-{safe_name}.yaml"
        },
    ]

    for test in tests:
        print(f"\nRunning: {test['name']}")

        chaos_dict = test["yaml_func"](safe_name)
        applied = apply_chaos(chaos_dict, test["path"])

        if not applied:
            results[test["key"]] = "FAIL"
            print(f"  Could not apply chaos — FAIL")
            continue

        recovered = check_recovery(safe_name)
        results[test["key"]] = "PASS" if recovered else "FAIL"
        print(f"  Recovery: {results[test['key']]}")

        delete_chaos(test["path"])
        time.sleep(10)

    # Final recovery validation
    print("\nRunning: Recovery Validation")
    final = check_recovery(safe_name)
    results["recovery_validation"] = "PASS" if final else "FAIL"
    print(f"  Final: {results['recovery_validation']}")

    return results
