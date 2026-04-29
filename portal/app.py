#!/usr/bin/env python3
"""
CyberBlueSOC Portal - Secure Python Flask Backend
Central access point for all security tools with authentication and HTTPS
"""

import os
import json
import subprocess
import logging
from datetime import datetime
from flask import Flask, render_template, jsonify, request, redirect, url_for, flash
from flask_cors import CORS
import threading
import time
import signal
import sys
import ssl

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('portal.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuration
PORT = int(os.environ.get('PORT', 5500))
HTTPS_PORT = int(os.environ.get('HTTPS_PORT', 5443))
CHANGELOG_FILE = 'changelog.json'
CONTAINER_STATUS_FILE = 'container_status.json'
SSL_CERT_PATH = os.environ.get('SSL_CERT_PATH', './ssl/cert.pem')
SSL_KEY_PATH = os.environ.get('SSL_KEY_PATH', './ssl/key.pem')
ENABLE_HTTPS = os.environ.get('ENABLE_HTTPS', 'true').lower() == 'true'

# Global flag for graceful shutdown
shutdown_flag = False


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    global shutdown_flag
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_flag = True
    sys.exit(0)


# Register signal handlers
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


class ChangelogManager:
    """Manages changelog entries for all system activities"""

    def __init__(self, changelog_file):
        self.changelog_file = changelog_file
        self.load_changelog()

    def load_changelog(self):
        """Load existing changelog from file"""
        try:
            if os.path.exists(self.changelog_file):
                with open(self.changelog_file, 'r') as f:
                    self.changelog = json.load(f)
            else:
                self.changelog = {
                    "entries": [],
                    "metadata": {
                        "created": datetime.now().isoformat(),
                        "version": "1.0.0",
                        "total_entries": 0
                    }
                }
                self.save_changelog()
        except Exception as e:
            logger.error(f"Error loading changelog: {e}")
            self.changelog = {"entries": [], "metadata": {
                "created": datetime.now().isoformat(), "version": "1.0.0", "total_entries": 0}}

    def save_changelog(self):
        """Save changelog to file"""
        try:
            with open(self.changelog_file, 'w') as f:
                json.dump(self.changelog, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving changelog: {e}")

    def add_entry(self, action, details, user="system", level="info"):
        """Add a new changelog entry"""
        entry = {
            "timestamp": datetime.now().isoformat(),
            "action": action,
            "details": details,
            "user": user,
            "level": level,
            "id": len(self.changelog["entries"]) + 1
        }

        self.changelog["entries"].append(entry)
        self.changelog["metadata"]["total_entries"] = len(
            self.changelog["entries"])
        self.save_changelog()

        logger.info(f"Changelog entry added: {action} - {details}")
        return entry

    def get_entries(self, limit=None, level=None):
        """Get changelog entries with optional filtering"""
        entries = self.changelog["entries"]

        if level:
            entries = [e for e in entries if e["level"] == level]

        if limit:
            entries = entries[-limit:]

        return entries

    def get_stats(self):
        """Get changelog statistics"""
        entries = self.changelog["entries"]
        stats = {
            "total_entries": len(entries),
            "by_level": {},
            "by_action": {},
            "recent_activity": len([e for e in entries if self._is_recent(e["timestamp"])])
        }

        for entry in entries:
            # Count by level
            level = entry["level"]
            stats["by_level"][level] = stats["by_level"].get(level, 0) + 1

            # Count by action
            action = entry["action"]
            stats["by_action"][action] = stats["by_action"].get(action, 0) + 1

        return stats

    def _is_recent(self, timestamp, hours=24):
        """Check if timestamp is within recent hours"""
        try:
            entry_time = datetime.fromisoformat(timestamp)
            return (datetime.now() - entry_time).total_seconds() < hours * 3600
        except:
            return False


class ContainerMonitor:
    """Monitors Docker container status for all tools"""

    def __init__(self, changelog_manager):
        self.changelog = changelog_manager
        self.previous_status = {}
        self.monitoring = False
        self.monitor_thread = None
        self.container_status = {}

    def start_monitoring(self):
        """Start container monitoring in background thread"""
        if not self.monitoring:
            self.monitoring = True
            self.monitor_thread = threading.Thread(
                target=self._monitor_loop, daemon=True)
            self.monitor_thread.start()
            logger.info("Container monitoring started")

    def stop_monitoring(self):
        """Stop container monitoring"""
        self.monitoring = False
        if self.monitor_thread:
            self.monitor_thread.join()
        logger.info("Container monitoring stopped")

    def _monitor_loop(self):
        """Background monitoring loop"""
        while self.monitoring:
            try:
                current_status = self.get_all_container_status()
                self._check_status_changes(current_status)
                self.container_status = current_status
                self.previous_status = {
                    name: status["status"] for name, status in current_status.items()}
                time.sleep(30)  # Check every 30 seconds
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                time.sleep(60)  # Wait longer on error

    def _check_status_changes(self, current_status):
        """Check for container status changes and log them"""
        current_containers = {name: status["status"]
                              for name, status in current_status.items()}

        for name, status_info in current_status.items():
            if name not in self.previous_status:
                # New container started
                self.changelog.add_entry(
                    "container_started",
                    f"Container '{name}' started with status: {status_info['status']}",
                    level="info"
                )
            elif self.previous_status[name] != status_info["status"]:
                # Container status changed
                self.changelog.add_entry(
                    "container_status_changed",
                    f"Container '{name}' status changed from '{self.previous_status[name]}' to '{status_info['status']}'",
                    level="warning"
                )

        # Check for stopped containers
        for name in self.previous_status:
            if name not in current_containers:
                self.changelog.add_entry(
                    "container_stopped",
                    f"Container '{name}' stopped",
                    level="warning"
                )

    def get_container_count(self):
        """Get running container count"""
        try:
            result = subprocess.run(
                ['docker', 'ps', '--format', 'table {{.Names}}'],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                return len(lines) - 1  # Subtract header line
            return 0
        except Exception as e:
            logger.error(f"Error getting container count: {e}")
            return 0

    def get_all_container_status(self):
        """Get detailed status for all containers"""
        try:
            result = subprocess.run(
                ['docker', 'ps', '-a', '--format',
                    '{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}\t{{.Size}}'],
                capture_output=True, text=True, timeout=10
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                containers = {}

                for line in lines:
                    if line.strip():
                        # Split by tab character
                        parts = line.split('\t')
                        if len(parts) >= 5:
                            name = parts[0].strip()
                            status = parts[1].strip()
                            ports = parts[2].strip()
                            image = parts[3].strip()
                            size = parts[4].strip()

                            # Determine status type
                            if "Up" in status:
                                status_type = "running"
                                status_color = "green"
                            elif "Exited" in status:
                                status_type = "stopped"
                                status_color = "red"
                            elif "Created" in status:
                                status_type = "created"
                                status_color = "yellow"
                            else:
                                status_type = "unknown"
                                status_color = "gray"

                            containers[name] = {
                                "name": name,
                                "status": status_type,
                                "status_text": status,
                                "status_color": status_color,
                                "ports": ports,
                                "image": image,
                                "size": size,
                                "last_updated": datetime.now().isoformat()
                            }

                return containers
            return {}
        except Exception as e:
            logger.error(f"Error getting container status: {e}")
            return {}

    def get_tool_container_status(self):
        """Get status for tool-specific containers"""
        all_containers = self.get_all_container_status()
        tool_containers = {}

        # Map tool names to possible container names (with fallbacks)
        tool_container_map = {
            "velociraptor": ["velociraptor"],
            "wazuh": ["wazuh", "wazuh-dashboard", "cyber-blue-test-wazuh.dashboard-1"],
            "wazuh-dashboard": ["wazuh", "wazuh-dashboard", "cyber-blue-test-wazuh.dashboard-1"],
            "misp": ["misp", "misp-core", "cyber-blue-test-misp-core-1"],
            "cyberchef": ["cyber-blue-test-cyberchef-1", "cyberchef"],
            "thehive": ["cyber-blue-test-thehive-1", "thehive"],
            "cortex": ["cyber-blue-test-cortex-1", "cortex"],
            "fleetdm": ["fleet-server", "cyber-blue-test-fleet-server-1"],
            "arkime": ["arkime-test", "arkime", "cyber-blue-test-arkime-1"],
            "caldera": ["caldera", "cyber-blue-test-caldera-1"],
            "evebox": ["evebox", "cyber-blue-test-evebox-1"],
            "mitre": ["mitre-navigator", "cyber-blue-test-mitre-navigator-1"],
            "mitre-navigator": ["mitre-navigator", "cyber-blue-test-mitre-navigator-1"],
            "portainer": ["portainer", "cyber-blue-test-portainer-1"],
            "shuffle": ["shuffle-frontend", "cyber-blue-test-shuffle-frontend-1"]
        }

        def find_container_name(possible_names):
            """Find the first matching container name from the list"""
            for name in possible_names:
                if name in all_containers:
                    return name
            return None

        for tool_name, possible_names in tool_container_map.items():
            container_name = find_container_name(possible_names)
            if container_name:
                tool_containers[tool_name] = all_containers[container_name]
            else:
                # Container not found
                tool_containers[tool_name] = {
                    "name": possible_names[0] if possible_names else tool_name,
                    "status": "not_found",
                    "status_text": "Container not found",
                    "status_color": "gray",
                    "ports": "",
                    "image": "",
                    "size": "",
                    "last_updated": datetime.now().isoformat()
                }

        return tool_containers

    def get_container_name_for_tool(self, tool_name):
        """Get the actual container name for a tool"""
        all_containers = self.get_all_container_status()

        # Map tool names to possible container names (with fallbacks)
        tool_container_map = {
            "velociraptor": ["velociraptor"],
            "wazuh": ["wazuh", "wazuh-dashboard", "cyber-blue-test-wazuh.dashboard-1"],
            "wazuh-dashboard": ["wazuh", "wazuh-dashboard", "cyber-blue-test-wazuh.dashboard-1"],
            "misp": ["misp", "misp-core", "cyber-blue-test-misp-core-1"],
            "cyberchef": ["cyber-blue-test-cyberchef-1", "cyberchef"],
            "thehive": ["cyber-blue-test-thehive-1", "thehive"],
            "cortex": ["cyber-blue-test-cortex-1", "cortex"],
            "fleetdm": ["fleet-server", "cyber-blue-test-fleet-server-1"],
            "arkime": ["arkime-test", "arkime", "cyber-blue-test-arkime-1"],
            "caldera": ["caldera", "cyber-blue-test-caldera-1"],
            "evebox": ["evebox", "cyber-blue-test-evebox-1"],
            "mitre": ["mitre-navigator", "cyber-blue-test-mitre-navigator-1"],
            "mitre-navigator": ["mitre-navigator", "cyber-blue-test-mitre-navigator-1"],
            "portainer": ["portainer", "cyber-blue-test-portainer-1"],
            "shuffle": ["shuffle-frontend", "cyber-blue-test-shuffle-frontend-1"]
        }

        if tool_name in tool_container_map:
            for name in tool_container_map[tool_name]:
                if name in all_containers:
                    return name

        # If not found in tool mapping, return the original name
        return tool_name

    def start_container(self, container_name):
        """Start a specific container"""
        try:
            # Try to find the actual container name if it's a tool name
            actual_container_name = self.get_container_name_for_tool(
                container_name)

            result = subprocess.run(
                ['docker', 'start', actual_container_name],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                self.changelog.add_entry(
                    "container_started",
                    f"Container '{actual_container_name}' started manually",
                    level="info"
                )
                return {"success": True, "message": f"Container {actual_container_name} started successfully"}
            else:
                return {"success": False, "message": f"Failed to start container: {result.stderr}"}
        except Exception as e:
            logger.error(f"Error starting container {container_name}: {e}")
            return {"success": False, "message": f"Error starting container: {str(e)}"}

    def stop_container(self, container_name):
        """Stop a specific container"""
        try:
            # Try to find the actual container name if it's a tool name
            actual_container_name = self.get_container_name_for_tool(
                container_name)

            result = subprocess.run(
                ['docker', 'stop', actual_container_name],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                self.changelog.add_entry(
                    "container_stopped",
                    f"Container '{actual_container_name}' stopped manually",
                    level="info"
                )
                return {"success": True, "message": f"Container {actual_container_name} stopped successfully"}
            else:
                return {"success": False, "message": f"Failed to stop container: {result.stderr}"}
        except Exception as e:
            logger.error(f"Error stopping container {container_name}: {e}")
            return {"success": False, "message": f"Error stopping container: {str(e)}"}

    def restart_container(self, container_name):
        """Restart a specific container"""
        try:
            # Try to find the actual container name if it's a tool name
            actual_container_name = self.get_container_name_for_tool(
                container_name)

            result = subprocess.run(
                ['docker', 'restart', actual_container_name],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode == 0:
                self.changelog.add_entry(
                    "container_restarted",
                    f"Container '{actual_container_name}' restarted manually",
                    level="info"
                )
                return {"success": True, "message": f"Container {actual_container_name} restarted successfully"}
            else:
                return {"success": False, "message": f"Failed to restart container: {result.stderr}"}
        except Exception as e:
            logger.error(f"Error restarting container {container_name}: {e}")
            return {"success": False, "message": f"Error restarting container: {str(e)}"}


# Initialize managers
changelog_manager = ChangelogManager(CHANGELOG_FILE)
container_monitor = ContainerMonitor(changelog_manager)


@app.route('/')
def index():
    """Main portal page - no authentication required"""
    changelog_manager.add_entry(
        action="portal_access",
        details="Portal accessed",
        user="anonymous",
        level="info"
    )
    return render_template('index.html')


@app.route('/api/containers')
def get_containers():
    """Get container count API endpoint"""
    try:
        count = container_monitor.get_container_count()
        changelog_manager.add_entry(
            "api_call", f"Container count requested: {count} containers")
        return jsonify({"count": count})
    except Exception as e:
        logger.error(f"Error in container count API: {e}")
        return jsonify({"count": "Unknown", "error": str(e)}), 500


@app.route('/api/containers/status')
def get_container_status():
    """Get detailed container status API endpoint"""
    try:
        containers = container_monitor.get_all_container_status()
        changelog_manager.add_entry(
            "api_call", f"Container status requested: {len(containers)} containers")
        return jsonify({"containers": containers})
    except Exception as e:
        logger.error(f"Error in container status API: {e}")
        return jsonify({"containers": {}, "error": str(e)}), 500


@app.route('/api/containers/tools')
def get_tool_container_status():
    """Get tool-specific container status API endpoint"""
    try:
        tool_containers = container_monitor.get_tool_container_status()
        changelog_manager.add_entry(
            "api_call", f"Tool container status requested: {len(tool_containers)} tools")
        return jsonify({"tool_containers": tool_containers})
    except Exception as e:
        logger.error(f"Error in tool container status API: {e}")
        return jsonify({"tool_containers": {}, "error": str(e)}), 500


@app.route('/api/containers/<container_name>/start', methods=['POST'])
def start_container(container_name):
    """Start a specific container API endpoint"""
    try:
        result = container_monitor.start_container(container_name)
        changelog_manager.add_entry(
            "container_action", f"Container '{container_name}' start requested", user="api_user")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error starting container {container_name}: {e}")
        return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500


@app.route('/api/containers/<container_name>/stop', methods=['POST'])
def stop_container(container_name):
    """Stop a specific container API endpoint"""
    try:
        result = container_monitor.stop_container(container_name)
        changelog_manager.add_entry(
            "container_action", f"Container '{container_name}' stop requested", user="api_user")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error stopping container {container_name}: {e}")
        return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500


@app.route('/api/containers/<container_name>/restart', methods=['POST'])
def restart_container(container_name):
    """Restart a specific container API endpoint"""
    try:
        result = container_monitor.restart_container(container_name)
        changelog_manager.add_entry(
            "container_action", f"Container '{container_name}' restart requested", user="api_user")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error restarting container {container_name}: {e}")
        return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500


@app.route('/api/containers/stats')
def get_container_stats():
    """Get container statistics API endpoint"""
    try:
        all_containers = container_monitor.get_all_container_status()
        tool_containers = container_monitor.get_tool_container_status()

        # Calculate statistics
        total_containers = len(all_containers)
        running_containers = len(
            [c for c in all_containers.values() if c["status"] == "running"])
        stopped_containers = len(
            [c for c in all_containers.values() if c["status"] == "stopped"])

        # Tool-specific stats
        tool_running = len(
            [c for c in tool_containers.values() if c["status"] == "running"])
        tool_stopped = len(
            [c for c in tool_containers.values() if c["status"] == "stopped"])
        tool_not_found = len(
            [c for c in tool_containers.values() if c["status"] == "not_found"])

        stats = {
            "total_containers": total_containers,
            "running_containers": running_containers,
            "stopped_containers": stopped_containers,
            "tool_containers": {
                "total": len(tool_containers),
                "running": tool_running,
                "stopped": tool_stopped,
                "not_found": tool_not_found
            },
            "health_percentage": round((running_containers / total_containers * 100) if total_containers > 0 else 0, 1),
            "last_updated": datetime.now().isoformat()
        }

        changelog_manager.add_entry(
            "api_call", f"Container stats requested: {stats['health_percentage']}% health")
        return jsonify(stats)
    except Exception as e:
        logger.error(f"Error in container stats API: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/changelog')
def get_changelog():
    """Get changelog entries API endpoint"""
    try:
        limit = request.args.get('limit', type=int)
        level = request.args.get('level')
        entries = changelog_manager.get_entries(limit=limit, level=level)
        return jsonify({"entries": entries})
    except Exception as e:
        logger.error(f"Error in changelog API: {e}")
        return jsonify({"entries": [], "error": str(e)}), 500


@app.route('/api/changelog/stats')
def get_changelog_stats():
    """Get changelog statistics API endpoint"""
    try:
        stats = changelog_manager.get_stats()
        return jsonify(stats)
    except Exception as e:
        logger.error(f"Error in changelog stats API: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/changelog/add', methods=['POST'])
def add_changelog_entry():
    """Add a new changelog entry API endpoint"""
    try:
        data = request.get_json()
        action = data.get('action', 'unknown')
        details = data.get('details', '')
        user = data.get('user', 'api_user')
        level = data.get('level', 'info')

        entry = changelog_manager.add_entry(action, details, user, level)
        return jsonify({"success": True, "entry": entry})
    except Exception as e:
        logger.error(f"Error adding changelog entry: {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/api/force-start', methods=['POST'])
def force_start_system():
    """Force start system by restarting Docker and bringing up all services"""
    try:
        # Detect the project directory dynamically
        def find_project_directory():
            """Find the CyberBlue project directory dynamically"""
            # Since we're running in a container, we need to check paths on the host system
            # We know the most likely location is /home/ubuntu/CyberBlue
            host_possible_paths = [
                '/home/ubuntu/CyberBlue',
                '/opt/CyberBlue',
                '/root/CyberBlue',
                '/home/*/CyberBlue',  # Wildcard for different users
            ]

            # First, try the most common location
            default_path = '/home/ubuntu/CyberBlue'
            logger.info(
                f"Using default CyberBlue project directory: {default_path}")
            return default_path

        project_dir = find_project_directory()

        changelog_manager.add_entry(
            "force_start_initiated",
            f"Force start system initiated from directory: {project_dir}",
            user='system',
            level="info"
        )

        # Execute the force start commands
        def run_force_start():
            try:
                # Since restarting Docker from within a container causes issues,
                # let's try a simpler approach: just restart the containers without restarting Docker daemon

                logger.info(
                    "Force starting containers without Docker daemon restart...")

                # Step 1: Stop all containers first
                logger.info("Stopping all containers...")
                stop_cmd = [
                    'docker', 'run', '--rm',
                    '-v', '/var/run/docker.sock:/var/run/docker.sock',
                    'alpine/docker:latest',
                    'sh', '-c', 'docker stop $(docker ps -q) 2>/dev/null || true'
                ]

                result1 = subprocess.run(
                    stop_cmd,
                    capture_output=True, text=True, timeout=60
                )

                logger.info(f"Container stop result: {result1.returncode}")
                if result1.stderr:
                    logger.info(f"Stop stderr: {result1.stderr}")

                # Step 2: Wait a moment
                logger.info("Waiting for containers to stop...")
                time.sleep(5)

                # Step 3: Start containers using docker compose from the host directory
                logger.info(f"Starting services in directory: {project_dir}")

                # Mount the project directory and run docker compose
                compose_cmd = [
                    'docker', 'run', '--rm',
                    '-v', '/var/run/docker.sock:/var/run/docker.sock',
                    '-v', f'{project_dir}:{project_dir}',
                    '-w', project_dir,
                    'alpine/docker:latest',
                    'sh', '-c', 'apk add --no-cache docker-compose && docker-compose up -d'
                ]

                result2 = subprocess.run(
                    compose_cmd,
                    capture_output=True, text=True, timeout=300  # 5 minutes timeout
                )

                logger.info(f"Docker compose result: {result2.returncode}")
                if result2.stdout:
                    logger.info(f"Compose stdout: {result2.stdout}")
                if result2.stderr:
                    logger.info(f"Compose stderr: {result2.stderr}")

                if result2.returncode != 0:
                    # Try alternative approach with docker compose (newer syntax)
                    logger.info("Trying with newer docker compose syntax...")
                    compose_cmd_alt = [
                        'docker', 'run', '--rm',
                        '-v', '/var/run/docker.sock:/var/run/docker.sock',
                        '-v', f'{project_dir}:{project_dir}',
                        '-w', project_dir,
                        'docker:latest',
                        'sh', '-c', 'docker compose up -d'
                    ]

                    result3 = subprocess.run(
                        compose_cmd_alt,
                        capture_output=True, text=True, timeout=300
                    )

                    logger.info(
                        f"Alternative compose result: {result3.returncode}")
                    if result3.stdout:
                        logger.info(f"Alt stdout: {result3.stdout}")
                    if result3.stderr:
                        logger.info(f"Alt stderr: {result3.stderr}")

                    if result3.returncode != 0:
                        changelog_manager.add_entry(
                            "force_start_failed",
                            f"Docker compose failed: {result2.stderr} | Alt: {result3.stderr}",
                            user='system',
                            level="error"
                        )
                        return False

                changelog_manager.add_entry(
                    "force_start_completed",
                    f"Force start completed successfully in {project_dir}",
                    user='system',
                    level="success"
                )
                return True

            except subprocess.TimeoutExpired:
                logger.error("Force start operation timed out")
                changelog_manager.add_entry(
                    "force_start_failed",
                    "Force start operation timed out",
                    user='system',
                    level="error"
                )
                return False
            except Exception as e:
                logger.error(f"Error during force start: {e}")
                changelog_manager.add_entry(
                    "force_start_failed",
                    f"Force start error: {str(e)}",
                    user='system',
                    level="error"
                )
                return False

        # Run the force start in a separate thread to avoid blocking the response
        import threading

        def async_force_start():
            success = run_force_start()
            if success:
                logger.info("Force start completed successfully")
            else:
                logger.error("Force start failed")

        force_start_thread = threading.Thread(
            target=async_force_start, daemon=True)
        force_start_thread.start()

        return jsonify({
            "success": True,
            "message": f"Force start initiated successfully in {project_dir}. This may take several minutes.",
            "project_directory": project_dir
        })

    except Exception as e:
        logger.error(f"Error in force start API: {e}")
        changelog_manager.add_entry(
            "force_start_error",
            f"Force start API error: {str(e)}",
            user='system',
            level="error"
        )
        return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500


@app.route('/api/server-info')
def get_server_info():
    """Get server information API endpoint"""
    try:
        import socket

        # Get the actual server IP (not localhost)
        def get_server_ip():
            try:
                # Priority 1: Use HOST_IP environment variable (set in Docker Compose)
                import os
                host_ip = os.environ.get('HOST_IP')
                if host_ip:
                    logger.info(
                        f"Using HOST_IP environment variable: {host_ip}")
                    return host_ip

                # Priority 2: Detect if we're in a container and try to find host IP
                if os.path.exists('/.dockerenv'):
                    logger.info(
                        "Detected container environment, attempting to find host IP")

                    # Try to get default gateway (Docker host)
                    try:
                        import subprocess
                        result = subprocess.run(['ip', 'route', 'show', 'default'],
                                                capture_output=True, text=True, timeout=5)
                        if result.returncode == 0:
                            for line in result.stdout.split('\n'):
                                if 'default via' in line:
                                    gateway = line.split('via')[1].split()[0]
                                    logger.info(f"Found gateway: {gateway}")

                                    # Try to detect the actual host IP from network interfaces
                                    try:
                                        # Get network interfaces to find the host network
                                        net_result = subprocess.run(['ip', 'addr', 'show'],
                                                                    capture_output=True, text=True, timeout=5)
                                        if net_result.returncode == 0:
                                            # Look for private IP addresses (avoiding localhost)
                                            import re
                                            # Match common private IP ranges: 10.x.x.x, 192.168.x.x, 172.16-31.x.x
                                            ip_pattern = r'inet ((?:10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(?:1[6-9]|2[0-9]|3[0-1])\.\d+\.\d+))/'
                                            matches = re.findall(
                                                ip_pattern, net_result.stdout)
                                            if matches:
                                                # Filter out localhost and use the first valid private IP
                                                valid_ips = [
                                                    ip for ip in matches if ip != '127.0.0.1']
                                                if valid_ips:
                                                    detected_host = valid_ips[0]
                                                    logger.info(
                                                        f"Detected host IP from network interfaces: {detected_host}")
                                                    return detected_host
                                    except Exception as e:
                                        logger.warning(
                                            f"Could not detect host IP from interfaces: {e}")

                                    # Fallback: Use gateway IP if it's a private IP
                                    if (gateway.startswith('10.') or
                                        gateway.startswith('192.168.') or
                                            gateway.startswith('172.')):
                                        logger.info(
                                            f"Using gateway as host IP: {gateway}")
                                        return gateway
                                    break
                    except Exception as e:
                        logger.warning(f"Could not determine gateway: {e}")

                # Priority 3: Traditional socket method for non-container environments
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                    s.connect(("8.8.8.8", 80))
                    detected_ip = s.getsockname()[0]

                    # If it's a container IP, try to find the host IP
                    if detected_ip.startswith('172.'):
                        logger.warning(
                            f"Detected container IP {detected_ip}, trying to find host IP")
                        # Try to find the actual host IP from request headers or environment
                        return request.environ.get('HTTP_X_FORWARDED_FOR',
                                                   request.environ.get('HTTP_X_REAL_IP',
                                                                       request.environ.get('REMOTE_ADDR', detected_ip)))

                    return detected_ip

            except Exception as e:
                logger.error(f"Error detecting server IP: {e}")
                # Final fallback - try to get from request context
                try:
                    return request.environ.get('HTTP_HOST', 'localhost').split(':')[0]
                except:
                    return 'localhost'

        server_ip = get_server_ip()
        hostname = socket.gethostname()

        return jsonify({
            "hostname": hostname,
            "server_ip": server_ip,
            "port": PORT,
            "portal_url": f"http://{server_ip}:{PORT}",
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        logger.error(f"Error getting server info: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/health')
def health_check():
    """Health check endpoint"""
    try:
        container_stats = container_monitor.get_container_count()
        return jsonify({
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "container_count": container_stats,
            "changelog_entries": len(changelog_manager.changelog["entries"]),
            "monitoring_active": container_monitor.monitoring
        })
    except Exception as e:
        logger.error(f"Error in health check: {e}")
        return jsonify({
            "status": "degraded",
            "timestamp": datetime.now().isoformat(),
            "error": str(e)
        }), 500


@app.route('/api/tools')
def get_tools():
    """Get available tools configuration"""
    tools = [
        {
            "name": "Velociraptor",
            "description": "Digital Forensics and Incident Response platform for live endpoint forensics and threat hunting.",
            "port": 7000,
            "icon": "fas fa-search",
            "category": "dfir",
            "categoryName": "DFIR",
            "protocols": ["https"],
            "credentials": {
                "username": "admin",
                "password": "cyberblue"
            }
        },
        {
            "name": "Wazuh Dashboard",
            "description": "SIEM dashboard for log analysis, alerting, and security monitoring with Kibana-style interface.",
            "port": 7001,
            "icon": "fas fa-chart-line",
            "category": "siem",
            "categoryName": "SIEM",
            "protocols": ["https"],
            "credentials": {
                "username": "admin",
                "password": "SecretPassword"
            }
        },
        {
            "name": "Shuffle",
            "description": "Security automation and orchestration platform for building, testing, and deploying security workflows.",
            "port": 7002,
            "icon": "fas fa-random",
            "category": "soar",
            "categoryName": "SOAR",
            "protocols": ["https"],
            "credentials": {
                "username": "admin",
                "password": "password"
            }
        },
        {
            "name": "MISP",
            "description": "Threat Intelligence Platform for sharing, storing, and correlating indicators of compromise.",
            "port": 7003,
            "icon": "fas fa-brain",
            "category": "cti",
            "categoryName": "CTI",
            "protocols": ["https"],
            "credentials": {
                "username": "admin@admin.test",
                "password": "admin"
            }
        },
        {
            "name": "CyberChef",
            "description": "Cyber Swiss Army Knife for data analysis, encoding, decoding, and forensics operations.",
            "port": 7004,
            "icon": "fas fa-utensils",
            "category": "utility",
            "categoryName": "Utility",
            "protocols": ["http"],
            "credentials": {
                "note": "No authentication required"
            }
        },
        {
            "name": "TheHive",
            "description": "Incident Response and Case Management platform for security operations teams.",
            "port": 7005,
            "icon": "fas fa-bug",
            "category": "soar",
            "categoryName": "SOAR",
            "protocols": ["http"],
            "credentials": {
                "username": "admin@thehive.local",
                "password": "secret"
            }
        },
        {
            "name": "Cortex",
            "description": "Automated threat analysis platform with analyzers for TheHive integration.",
            "port": 7006,
            "icon": "fas fa-robot",
            "category": "soar",
            "categoryName": "SOAR",
            "protocols": ["http"],
            "credentials": {
                "username": "admin",
                "password": "admin"
            }
        },
        {
            "name": "FleetDM",
            "description": "Osquery-based endpoint visibility and fleet management platform.",
            "port": 7007,
            "icon": "fas fa-desktop",
            "category": "management",
            "categoryName": "Management",
            "protocols": ["http"],
            "credentials": {
                "username": "admin",
                "password": "admin123"
            }
        },
        {
            "name": "Arkime",
            "description": "Full packet capture and session search engine for network analysis.",
            "port": 7008,
            "icon": "fas fa-network-wired",
            "category": "network analysis",
            "categoryName": "NETWORK ANALYSIS",
            "protocols": ["http"],
            "credentials": {
                "username": "admin",
                "password": "admin"
            }
        },
        {
            "name": "Caldera",
            "description": "Automated adversary emulation platform for security testing and red team operations.",
            "port": 7009,
            "icon": "fas fa-chess-king",
            "category": "attack-simulation",
            "categoryName": "ATTACK SIMULATION",
            "protocols": ["http"],
            "credentials": {
                "username": "admin",
                "password": "admin"
            }
        },
        {
            "name": "Evebox",
            "description": "Web-based viewer for Suricata EVE JSON logs and alert management.",
            "port": 7015,
            "icon": "fas fa-eye",
            "category": "ids",
            "categoryName": "INTRUSION DETECTION",
            "protocols": ["https"],
            "credentials": {
                "note": "No authentication required"
            }
        },
        {
            "name": "MITRE Navigator",
            "description": "Interactive ATT&CK matrix for threat modeling and attack path visualization.",
            "port": 7013,
            "icon": "fas fa-sitemap",
            "category": "cti",
            "categoryName": "CTI",
            "protocols": ["http"],
            "credentials": {
                "note": "No authentication required"
            }
        },
        {
            "name": "Portainer",
            "description": "Web-based container management interface for Docker and Kubernetes. ⚠️ NOTE: RESTART to be able to set the password!",
            "port": 9443,
            "icon": "fas fa-ship",
            "category": "management",
            "categoryName": "Management",
            "protocols": ["https"],
            "credentials": {
                "username": "admin",
                "password": "cyberblue123"
            }
        }
    ]
    return jsonify({"tools": tools})


@app.route('/api/dashboard/metrics')
def get_dashboard_metrics():
    """Get comprehensive dashboard metrics for enhanced visualization"""
    try:
        import psutil
        import time
        from datetime import datetime, timedelta

        # System metrics
        cpu_percent = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')

        # Container metrics
        all_containers = container_monitor.get_all_container_status()
        tool_containers = container_monitor.get_tool_container_status()

        running_containers = len(
            [c for c in all_containers.values() if c["status"] == "running"])
        stopped_containers = len(
            [c for c in all_containers.values() if c["status"] == "stopped"])
        total_containers = len(all_containers)

        # Tool-specific health
        tool_health = {}
        for tool_name, container_info in tool_containers.items():
            tool_health[tool_name] = {
                "status": container_info["status"],
                "health": "healthy" if container_info["status"] == "running" else "unhealthy",
                "uptime": container_info.get("status_text", "unknown")
            }

        # Security categories health
        categories = {
            "dfir": ["velociraptor"],
            "siem": ["wazuh", "wazuh-dashboard"],
            "soar": ["shuffle", "thehive", "cortex", "caldera"],
            "cti": ["misp", "mitre-navigator"],
            "ids": ["evebox"],
            "network analysis": ["arkime"],
            "utility": ["cyberchef"],
            "management": ["fleetdm", "portainer"]
        }

        category_health = {}
        for category, tools in categories.items():
            healthy_tools = 0
            total_tools = len(tools)
            for tool in tools:
                if tool in tool_containers and tool_containers[tool]["status"] == "running":
                    healthy_tools += 1

            health_percentage = (
                healthy_tools / total_tools * 100) if total_tools > 0 else 0
            category_health[category] = {
                "health_percentage": round(health_percentage, 1),
                "healthy_tools": healthy_tools,
                "total_tools": total_tools,
                "status": "healthy" if health_percentage >= 80 else "degraded" if health_percentage >= 50 else "critical"
            }

        # Recent activity from changelog
        recent_entries = changelog_manager.get_entries(limit=10)
        activity_summary = {
            "container_starts": len([e for e in recent_entries if "started" in e.get("action", "")]),
            "container_stops": len([e for e in recent_entries if "stopped" in e.get("action", "")]),
            "api_calls": len([e for e in recent_entries if "api_call" in e.get("action", "")]),
            "errors": len([e for e in recent_entries if e.get("level") == "error"])
        }

        metrics = {
            "timestamp": datetime.now().isoformat(),
            "system": {
                "cpu_percent": round(cpu_percent, 1),
                "memory_percent": round(memory.percent, 1),
                "memory_used_gb": round(memory.used / (1024**3), 2),
                "memory_total_gb": round(memory.total / (1024**3), 2),
                "disk_percent": round(disk.percent, 1),
                "disk_used_gb": round(disk.used / (1024**3), 2),
                "disk_total_gb": round(disk.total / (1024**3), 2)
            },
            "containers": {
                "total": total_containers,
                "running": running_containers,
                "stopped": stopped_containers,
                "health_percentage": round((running_containers / total_containers * 100) if total_containers > 0 else 0, 1)
            },
            "tools": tool_health,
            "categories": category_health,
            "activity": activity_summary,
            "uptime": datetime.now().isoformat()
        }

        changelog_manager.add_entry("api_call", "Dashboard metrics requested")
        return jsonify(metrics)

    except Exception as e:
        logger.error(f"Error getting dashboard metrics: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/dashboard/trends')
def get_dashboard_trends():
    """Get trending data for charts and graphs"""
    try:
        # For now, we'll generate sample trending data
        # In a real implementation, this would come from a time-series database
        from datetime import datetime, timedelta
        import random

        now = datetime.now()
        hours = []
        cpu_data = []
        memory_data = []
        container_data = []

        # Generate 24 hours of sample data
        for i in range(24):
            timestamp = now - timedelta(hours=23-i)
            hours.append(timestamp.strftime("%H:%M"))

            # Simulate realistic trending data
            cpu_data.append(round(random.uniform(10, 80), 1))
            memory_data.append(round(random.uniform(30, 90), 1))
            container_data.append(random.randint(25, 28))

        trends = {
            "timestamp": now.isoformat(),
            "timeframe": "24h",
            "data": {
                "labels": hours,
                "cpu_usage": cpu_data,
                "memory_usage": memory_data,
                "container_count": container_data
            }
        }

        changelog_manager.add_entry("api_call", "Dashboard trends requested")
        return jsonify(trends)

    except Exception as e:
        logger.error(f"Error getting dashboard trends: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/dashboard/security-events')
def get_security_events():
    """Get recent security-related events and alerts"""
    try:
        # Get recent changelog entries related to security
        recent_entries = changelog_manager.get_entries(limit=50)

        security_events = []
        for entry in recent_entries:
            # Classify events as security-related
            action = entry.get("action", "")
            details = entry.get("details", "")
            level = entry.get("level", "info")

            if any(keyword in action.lower() or keyword in details.lower()
                   for keyword in ["container_stopped", "container_started", "error", "failed", "warning"]):

                # Determine event severity
                if level == "error" or "failed" in details.lower():
                    severity = "high"
                    icon = "fas fa-exclamation-triangle"
                    color = "danger"
                elif level == "warning" or "stopped" in action:
                    severity = "medium"
                    icon = "fas fa-exclamation-circle"
                    color = "warning"
                else:
                    severity = "low"
                    icon = "fas fa-info-circle"
                    color = "info"

                security_events.append({
                    "id": entry.get("id"),
                    "timestamp": entry.get("timestamp"),
                    "title": action.replace("_", " ").title(),
                    "description": details,
                    "severity": severity,
                    "icon": icon,
                    "color": color,
                    "user": entry.get("user", "system")
                })

        # Limit to 20 most recent events
        security_events = security_events[:20]

        # Event statistics
        event_stats = {
            "total": len(security_events),
            "high": len([e for e in security_events if e["severity"] == "high"]),
            "medium": len([e for e in security_events if e["severity"] == "medium"]),
            "low": len([e for e in security_events if e["severity"] == "low"])
        }

        result = {
            "timestamp": datetime.now().isoformat(),
            "events": security_events,
            "statistics": event_stats
        }

        changelog_manager.add_entry(
            "api_call", f"Security events requested: {len(security_events)} events")
        return jsonify(result)

    except Exception as e:
        logger.error(f"Error getting security events: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/api/dashboard/network-stats')
def get_network_stats():
    """Get network statistics for containers and system"""
    try:
        import psutil

        # Get network interface statistics
        network_stats = psutil.net_io_counters()

        # Docker network information
        try:
            result = subprocess.run(
                ['docker', 'network', 'ls', '--format',
                    '{{.Name}}\t{{.Driver}}\t{{.Scope}}'],
                capture_output=True, text=True, timeout=10
            )

            networks = []
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    if line.strip():
                        parts = line.split('\t')
                        if len(parts) >= 3:
                            networks.append({
                                "name": parts[0],
                                "driver": parts[1],
                                "scope": parts[2]
                            })
        except Exception:
            networks = []

        # Container port mappings
        all_containers = container_monitor.get_all_container_status()
        active_ports = []
        for container in all_containers.values():
            if container["status"] == "running" and container["ports"]:
                ports = container["ports"]
                if ports and ports != "":
                    active_ports.append({
                        "container": container["name"],
                        "ports": ports
                    })

        stats = {
            "timestamp": datetime.now().isoformat(),
            "system_network": {
                "bytes_sent": network_stats.bytes_sent,
                "bytes_recv": network_stats.bytes_recv,
                "packets_sent": network_stats.packets_sent,
                "packets_recv": network_stats.packets_recv,
                "errors_in": network_stats.errin,
                "errors_out": network_stats.errout
            },
            "docker_networks": networks,
            "active_ports": active_ports,
            "network_health": "healthy" if len(networks) > 0 else "warning"
        }

        changelog_manager.add_entry("api_call", "Network stats requested")
        return jsonify(stats)

    except Exception as e:
        logger.error(f"Error getting network stats: {e}")
        return jsonify({"error": str(e)}), 500


# ============================================================================
# YARA & Sigma Hunting Rules Management API
# ============================================================================

@app.route('/api/hunting/yara/stats')
def get_yara_stats():
    """Get YARA installation statistics"""
    try:
        result = subprocess.run(['yara', '--version'],
                                capture_output=True, text=True, timeout=5)
        version = result.stdout.strip() if result.returncode == 0 else "Unknown"

        # Count rules
        yara_rules_path = "/opt/yara-rules"
        if os.path.exists(yara_rules_path):
            rule_files = subprocess.run(
                ['find', yara_rules_path, '-name', '*.yar', '-type', 'f'],
                capture_output=True, text=True, timeout=10
            )
            total_rules = len(rule_files.stdout.strip().split(
                '\n')) if rule_files.stdout.strip() else 0

            # Get categories
            categories = []
            if os.path.exists(yara_rules_path):
                for item in os.listdir(yara_rules_path):
                    item_path = os.path.join(yara_rules_path, item)
                    if os.path.isdir(item_path) and not item.startswith('.'):
                        cat_rules = subprocess.run(
                            ['find', item_path, '-name', '*.yar', '-type', 'f'],
                            capture_output=True, text=True, timeout=5
                        )
                        count = len(cat_rules.stdout.strip().split(
                            '\n')) if cat_rules.stdout.strip() else 0
                        categories.append({
                            'name': item,
                            'count': count,
                            'path': item_path
                        })
        else:
            total_rules = 0
            categories = []

        # Check last update
        last_update = "Never"
        if os.path.exists('/var/log/yara-update.log'):
            try:
                with open('/var/log/yara-update.log', 'r') as f:
                    lines = f.readlines()
                    if lines:
                        last_update = lines[-1].strip()[:50]
            except:
                pass

        stats = {
            'installed': os.path.exists('/usr/bin/yara'),
            'version': version,
            'total_rules': total_rules,
            'rules_path': yara_rules_path,
            'categories': categories,
            'last_update': last_update
        }

        return jsonify(stats)
    except Exception as e:
        logger.error(f"Error getting YARA stats: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/hunting/sigma/stats')
def get_sigma_stats():
    """Get Sigma installation statistics"""
    try:
        result = subprocess.run(['sigma', 'version'],
                                capture_output=True, text=True, timeout=5)
        version = result.stdout.strip().split(
            '\n')[0] if result.returncode == 0 else "Unknown"

        # Count rules
        sigma_rules_path = "/opt/sigma-rules/rules"
        if os.path.exists(sigma_rules_path):
            rule_files = subprocess.run(
                ['find', sigma_rules_path, '-name', '*.yml', '-type', 'f'],
                capture_output=True, text=True, timeout=10
            )
            total_rules = len(rule_files.stdout.strip().split(
                '\n')) if rule_files.stdout.strip() else 0

            # Get main categories
            categories = []
            if os.path.exists(sigma_rules_path):
                for item in os.listdir(sigma_rules_path):
                    item_path = os.path.join(sigma_rules_path, item)
                    if os.path.isdir(item_path):
                        cat_rules = subprocess.run(
                            ['find', item_path, '-name', '*.yml', '-type', 'f'],
                            capture_output=True, text=True, timeout=5
                        )
                        count = len(cat_rules.stdout.strip().split(
                            '\n')) if cat_rules.stdout.strip() else 0
                        categories.append({
                            'name': item,
                            'count': count,
                            'path': item_path
                        })
        else:
            total_rules = 0
            categories = []

        # Check last update
        last_update = "Never"
        if os.path.exists('/var/log/sigma-update.log'):
            try:
                with open('/var/log/sigma-update.log', 'r') as f:
                    lines = f.readlines()
                    if lines:
                        last_update = lines[-1].strip()[:50]
            except:
                pass

        stats = {
            'installed': os.path.exists('/usr/local/bin/sigma'),
            'version': version,
            'total_rules': total_rules,
            'rules_path': sigma_rules_path,
            'categories': categories,
            'last_update': last_update
        }

        return jsonify(stats)
    except Exception as e:
        logger.error(f"Error getting Sigma stats: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/hunting/update', methods=['POST'])
def update_hunting_rules():
    """Trigger manual update of YARA and Sigma rules"""
    try:
        data = request.get_json() or {}
        rule_type = data.get('type', 'all')  # 'yara', 'sigma', or 'all'

        results = {}

        if rule_type in ['yara', 'all']:
            # Update YARA rules
            yara_result = subprocess.run(
                ['git', '-C', '/opt/yara-rules', 'pull'],
                capture_output=True, text=True, timeout=30
            )
            results['yara'] = {
                'success': yara_result.returncode == 0,
                'output': yara_result.stdout + yara_result.stderr,
                'timestamp': datetime.now().isoformat()
            }

            # Log update
            with open('/var/log/yara-update.log', 'a') as f:
                f.write(
                    f"{datetime.now().isoformat()} - Manual update: {yara_result.stdout}\n")

            changelog_manager.add_entry(
                "yara_update",
                f"YARA rules manually updated: {yara_result.stdout.strip()[:100]}",
                user="portal",
                level="info"
            )

        if rule_type in ['sigma', 'all']:
            # Update Sigma rules
            sigma_result = subprocess.run(
                ['git', '-C', '/opt/sigma-rules', 'pull'],
                capture_output=True, text=True, timeout=30
            )
            results['sigma'] = {
                'success': sigma_result.returncode == 0,
                'output': sigma_result.stdout + sigma_result.stderr,
                'timestamp': datetime.now().isoformat()
            }

            # Log update
            with open('/var/log/sigma-update.log', 'a') as f:
                f.write(
                    f"{datetime.now().isoformat()} - Manual update: {sigma_result.stdout}\n")

            changelog_manager.add_entry(
                "sigma_update",
                f"Sigma rules manually updated: {sigma_result.stdout.strip()[:100]}",
                user="portal",
                level="info"
            )

        return jsonify({
            'success': True,
            'results': results,
            'message': f'Update completed for {rule_type}'
        })

    except Exception as e:
        logger.error(f"Error updating hunting rules: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/hunting/cron/status')
def get_cron_status():
    """Get auto-update cron job status"""
    try:
        result = subprocess.run(
            ['crontab', '-l'],
            capture_output=True, text=True, timeout=5
        )

        if result.returncode == 0:
            cron_lines = result.stdout.strip().split('\n')
            yara_cron = [
                line for line in cron_lines if 'yara-rules' in line and not line.startswith('#')]
            sigma_cron = [
                line for line in cron_lines if 'sigma-rules' in line and not line.startswith('#')]

            return jsonify({
                'enabled': len(yara_cron) > 0 or len(sigma_cron) > 0,
                'yara_schedule': yara_cron[0] if yara_cron else None,
                'sigma_schedule': sigma_cron[0] if sigma_cron else None,
                'full_crontab': cron_lines
            })
        else:
            return jsonify({
                'enabled': False,
                'error': 'No crontab configured'
            })

    except Exception as e:
        logger.error(f"Error getting cron status: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/hunting/logs')
def get_hunting_logs():
    """Get YARA and Sigma update logs"""
    try:
        log_type = request.args.get('type', 'all')
        lines = int(request.args.get('lines', 50))

        logs = {}

        if log_type in ['yara', 'all']:
            if os.path.exists('/var/log/yara-update.log'):
                with open('/var/log/yara-update.log', 'r') as f:
                    all_lines = f.readlines()
                    logs['yara'] = all_lines[-lines:] if len(
                        all_lines) > lines else all_lines
            else:
                logs['yara'] = []

        if log_type in ['sigma', 'all']:
            if os.path.exists('/var/log/sigma-update.log'):
                with open('/var/log/sigma-update.log', 'r') as f:
                    all_lines = f.readlines()
                    logs['sigma'] = all_lines[-lines:] if len(
                        all_lines) > lines else all_lines
            else:
                logs['sigma'] = []

        return jsonify(logs)

    except Exception as e:
        logger.error(f"Error getting hunting logs: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/hunting/yara/scan', methods=['POST'])
def run_yara_scan():
    """Run YARA scan on specified path"""
    try:
        data = request.get_json() or {}
        target_path = data.get('path', '/tmp')
        rule_category = data.get('category', 'malware_index.yar')

        # Security: Prevent directory traversal
        if '..' in target_path or target_path.startswith('/opt/yara-rules'):
            return jsonify({'success': False, 'error': 'Invalid path'}), 400

        rule_path = f"/opt/yara-rules/{rule_category}"
        if not os.path.exists(rule_path):
            return jsonify({'success': False, 'error': f'Rule file not found: {rule_category}'}), 404

        # Run YARA scan
        result = subprocess.run(
            ['yara', '-r', rule_path, target_path],
            capture_output=True, text=True, timeout=60
        )

        matches = result.stdout.strip().split('\n') if result.stdout.strip() else []

        changelog_manager.add_entry(
            "yara_scan",
            f"YARA scan executed: {target_path} with {rule_category}, {len(matches)} matches",
            user="portal",
            level="info"
        )

        return jsonify({
            'success': True,
            'matches': matches,
            'match_count': len(matches),
            'target_path': target_path,
            'rule_used': rule_category,
            'timestamp': datetime.now().isoformat()
        })

    except subprocess.TimeoutExpired:
        return jsonify({'success': False, 'error': 'Scan timeout (60s exceeded)'}), 500
    except Exception as e:
        logger.error(f"Error running YARA scan: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/hunting/sigma/convert', methods=['POST'])
def convert_sigma_rule():
    """Convert Sigma rule to target format"""
    try:
        data = request.get_json() or {}
        rule_path = data.get('rule_path', '')
        target = data.get('target', 'opensearch_lucene')

        # Security: Prevent directory traversal
        if '..' in rule_path or not rule_path.startswith('/opt/sigma-rules'):
            return jsonify({'success': False, 'error': 'Invalid rule path'}), 400

        if not os.path.exists(rule_path):
            return jsonify({'success': False, 'error': 'Rule file not found'}), 404

        # Run Sigma conversion
        result = subprocess.run(
            ['sigma', 'convert', '-t', target, '--without-pipeline', rule_path],
            capture_output=True, text=True, timeout=30
        )

        if result.returncode == 0:
            changelog_manager.add_entry(
                "sigma_convert",
                f"Sigma rule converted: {os.path.basename(rule_path)} to {target}",
                user="portal",
                level="info"
            )

            return jsonify({
                'success': True,
                'converted_rule': result.stdout,
                'target': target,
                'source_file': os.path.basename(rule_path),
                'timestamp': datetime.now().isoformat()
            })
        else:
            return jsonify({
                'success': False,
                'error': result.stderr,
                'stdout': result.stdout
            }), 400

    except Exception as e:
        logger.error(f"Error converting Sigma rule: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/hunting/sigma/rules')
def list_sigma_rules():
    """List available Sigma rules by category"""
    try:
        category = request.args.get('category', '')
        limit = int(request.args.get('limit', 100))

        sigma_base = "/opt/sigma-rules/rules"
        search_path = os.path.join(
            sigma_base, category) if category else sigma_base

        if not os.path.exists(search_path):
            return jsonify({'error': 'Category not found'}), 404

        # Find rules
        result = subprocess.run(
            ['find', search_path, '-name', '*.yml', '-type', 'f'],
            capture_output=True, text=True, timeout=10
        )

        rule_files = result.stdout.strip().split('\n') if result.stdout.strip() else []
        rule_files = [f for f in rule_files if f][:limit]

        rules = []
        for rule_file in rule_files:
            rel_path = rule_file.replace('/opt/sigma-rules/', '')
            rules.append({
                'name': os.path.basename(rule_file),
                'path': rule_file,
                'relative_path': rel_path,
                'category': rel_path.split('/')[1] if '/' in rel_path else 'unknown',
                'size': os.path.getsize(rule_file) if os.path.exists(rule_file) else 0
            })

        return jsonify({
            'rules': rules,
            'total': len(rules),
            'category': category or 'all'
        })

    except Exception as e:
        logger.error(f"Error listing Sigma rules: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/hunting/yara/rules')
def list_yara_rules():
    """List available YARA rules by category"""
    try:
        category = request.args.get('category', '')

        yara_base = "/opt/yara-rules"
        search_path = os.path.join(
            yara_base, category) if category else yara_base

        if not os.path.exists(search_path):
            return jsonify({'error': 'Category not found'}), 404

        # Find rule files
        result = subprocess.run(
            ['find', search_path, '-name', '*.yar', '-type', 'f'],
            capture_output=True, text=True, timeout=10
        )

        rule_files = result.stdout.strip().split('\n') if result.stdout.strip() else []
        rule_files = [f for f in rule_files if f]

        rules = []
        for rule_file in rule_files:
            rel_path = rule_file.replace('/opt/yara-rules/', '')
            rules.append({
                'name': os.path.basename(rule_file),
                'path': rule_file,
                'relative_path': rel_path,
                'category': os.path.dirname(rel_path).split('/')[0] if '/' in rel_path else 'root',
                'size': os.path.getsize(rule_file) if os.path.exists(rule_file) else 0
            })

        return jsonify({
            'rules': rules,
            'total': len(rules),
            'category': category or 'all'
        })

    except Exception as e:
        logger.error(f"Error listing YARA rules: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/hunting/rule/content')
def get_rule_content():
    """Get content of a specific rule file"""
    try:
        rule_path = request.args.get('path', '')

        # Security: Ensure path is within allowed directories
        if not rule_path.startswith('/opt/yara-rules/') and not rule_path.startswith('/opt/sigma-rules/'):
            return jsonify({'error': 'Invalid path - must be in yara-rules or sigma-rules'}), 400

        # Prevent directory traversal
        if '..' in rule_path:
            return jsonify({'error': 'Invalid path'}), 400

        if not os.path.exists(rule_path):
            return jsonify({'error': 'Rule file not found'}), 404

        # Read file content
        with open(rule_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        return jsonify({
            'success': True,
            'content': content,
            'path': rule_path,
            'name': os.path.basename(rule_path),
            'size': os.path.getsize(rule_path)
        })

    except Exception as e:
        logger.error(f"Error reading rule content: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# Velociraptor Agent Generation API
# ============================================================================

def extract_ca_certificate():
    """Extract CA certificate from Velociraptor server config"""
    try:
        server_config_path = '/velociraptor/server.config.yaml'
        if not os.path.exists(server_config_path):
            logger.error(f"Server config not found at {server_config_path}")
            return None

        with open(server_config_path, 'r') as f:
            lines = f.readlines()

        # Find the CA certificate section
        ca_cert_lines = []
        in_ca_section = False
        indent_to_match = None

        for line in lines:
            if 'ca_certificate:' in line and 'Client:' in ''.join(lines[max(0, lines.index(line)-10):lines.index(line)]):
                in_ca_section = True
                # Get the indentation level of the next line
                continue

            if in_ca_section:
                # Detect indentation
                if indent_to_match is None and line.strip().startswith('-----BEGIN CERTIFICATE-----'):
                    indent_to_match = len(line) - len(line.lstrip())

                if indent_to_match is not None:
                    current_indent = len(line) - len(line.lstrip())

                    # If we hit a line with less or equal indentation (and it's not part of cert), we're done
                    if current_indent <= indent_to_match and line.strip() and not line.strip().startswith('-----'):
                        if '-----END CERTIFICATE-----' in ''.join(ca_cert_lines):
                            break

                    # Add the line (removing the YAML indentation)
                    if line.strip():
                        ca_cert_lines.append(line[indent_to_match:].rstrip())

                    if '-----END CERTIFICATE-----' in line:
                        break

        if ca_cert_lines:
            ca_certificate = '\n'.join(ca_cert_lines)
            logger.info(
                "Successfully extracted CA certificate from server config")
            return ca_certificate
        else:
            logger.error("Could not extract CA certificate from server config")
            return None

    except Exception as e:
        logger.error(f"Error extracting CA certificate: {e}")
        return None


@app.route('/api/agents/generate', methods=['POST'])
def generate_agent_configs():
    """Generate Velociraptor agent package (binary + config) for given server IP and OS"""
    try:
        import zipfile
        import shutil
        import uuid
        import re

        data = request.get_json()
        # velociraptor or wazuh
        agent_type = data.get('agent_type', 'velociraptor').lower()
        server_ip = data.get('server_ip', '').strip()
        os_type = data.get('os_type', '').lower()

        if not server_ip:
            return jsonify({'success': False, 'error': 'Server IP is required'}), 400

        if not os_type:
            return jsonify({'success': False, 'error': 'OS type is required'}), 400

        # Validate IP format
        ip_pattern = r'^(\d{1,3}\.){3}\d{1,3}$'
        if not re.match(ip_pattern, server_ip):
            return jsonify({'success': False, 'error': 'Invalid IP address format'}), 400

        # Branch based on agent type
        if agent_type == 'velociraptor':
            # Validate OS type for Velociraptor
            valid_os_types = ['windows', 'linux', 'macos-intel', 'macos-arm']
            if os_type not in valid_os_types:
                return jsonify({'success': False, 'error': f'Invalid OS type for Velociraptor'}), 400

            # Extract CA certificate from server config
            ca_certificate = extract_ca_certificate()
            if not ca_certificate:
                return jsonify({'success': False, 'error': 'Could not extract CA certificate from server config'}), 500

            # Setup for Velociraptor
            session_id = str(uuid.uuid4())[:8]
            session_dir = f'/velociraptor/agents/generated/{session_id}'
            os.makedirs(session_dir, exist_ok=True)

            binary_map = {
                'windows': ('velociraptor-windows.exe', 'INSTALL_WINDOWS.txt', 'velociraptor-windows.exe'),
                'linux': ('velociraptor-linux', 'INSTALL_LINUX.txt', 'velociraptor'),
                'macos-intel': ('velociraptor-macos-intel', 'INSTALL_MACOS.txt', 'velociraptor'),
                'macos-arm': ('velociraptor-macos-arm', 'INSTALL_MACOS.txt', 'velociraptor')
            }

            binary_file, instruction_file, target_binary_name = binary_map[os_type]
            binary_path = f'/velociraptor/agents/binaries/{binary_file}'
            template_dir = '/velociraptor/agents/templates'

            if not os.path.exists(binary_path):
                return jsonify({'success': False, 'error': f'Binary not found for {os_type}'}), 500

            # Generate client.config.yaml
            with open(f'{template_dir}/client.config.template.yaml', 'r') as f:
                client_config = f.read()
            ca_cert_indented = '\n'.join(
                ['    ' + line for line in ca_certificate.split('\n')])
            client_config = client_config.replace('{{SERVER_IP}}', server_ip)
            client_config = client_config.replace(
                '{{CA_CERTIFICATE}}', ca_cert_indented)

            # Generate instructions
            with open(f'{template_dir}/{instruction_file}', 'r') as f:
                instructions = f.read()
            instructions = instructions.replace('{{SERVER_IP}}', server_ip)

            # Create package
            package_name = f'velociraptor-agent-{os_type}'
            package_dir = f'{session_dir}/{package_name}'
            os.makedirs(package_dir, exist_ok=True)

            shutil.copy(binary_path, f'{package_dir}/{target_binary_name}')
            with open(f'{package_dir}/client.config.yaml', 'w') as f:
                f.write(client_config)
            with open(f'{package_dir}/INSTALL.txt', 'w') as f:
                f.write(instructions)

        # ==================== WAZUH ====================
        elif agent_type == 'wazuh':
            # Validate OS type for Wazuh
            valid_os_types = ['windows', 'ubuntu', 'centos']
            if os_type not in valid_os_types:
                return jsonify({'success': False, 'error': f'Invalid OS type for Wazuh'}), 400

            # Setup for Wazuh
            session_id = str(uuid.uuid4())[:8]
            session_dir = f'/wazuh/agents/generated/{session_id}'
            os.makedirs(session_dir, exist_ok=True)

            wazuh_binary_map = {
                'windows': ('wazuh-agent-windows.msi', 'INSTALL_WINDOWS.txt', 'wazuh-agent-windows.msi'),
                'ubuntu': ('wazuh-agent-ubuntu.deb', 'INSTALL_LINUX_DEB.txt', 'wazuh-agent-ubuntu.deb'),
                'centos': ('wazuh-agent-centos.rpm', 'INSTALL_LINUX_RPM.txt', 'wazuh-agent-centos.rpm')
            }

            binary_file, instruction_file, target_binary_name = wazuh_binary_map[os_type]
            binary_path = f'/wazuh/agents/binaries/{binary_file}'
            template_dir = '/wazuh/agents/templates'

            if not os.path.exists(binary_path):
                return jsonify({'success': False, 'error': f'Package not found for {os_type}'}), 500

            # Generate ossec.conf
            with open(f'{template_dir}/ossec.conf.template', 'r') as f:
                ossec_config = f.read()
            ossec_config = ossec_config.replace('{{MANAGER_IP}}', server_ip)

            # Generate instructions
            with open(f'{template_dir}/{instruction_file}', 'r') as f:
                instructions = f.read()
            instructions = instructions.replace('{{MANAGER_IP}}', server_ip)

            # Create package
            package_name = f'wazuh-agent-{os_type}'
            package_dir = f'{session_dir}/{package_name}'
            os.makedirs(package_dir, exist_ok=True)

            shutil.copy(binary_path, f'{package_dir}/{target_binary_name}')
            with open(f'{package_dir}/ossec.conf', 'w') as f:
                f.write(ossec_config)
            with open(f'{package_dir}/INSTALL.txt', 'w') as f:
                f.write(instructions)

        # ==================== CALDERA ====================
        elif agent_type == 'caldera':
            # Validate OS type for Caldera
            valid_os_types = ['windows', 'linux', 'macos']
            if os_type not in valid_os_types:
                return jsonify({'success': False, 'error': f'Invalid OS type for Caldera'}), 400

            # Setup for Caldera
            session_id = str(uuid.uuid4())[:8]
            session_dir = f'/caldera/agents/generated/{session_id}'
            os.makedirs(session_dir, exist_ok=True)

            template_dir = '/caldera/agents/templates'

            # Map OS to deployment instructions
            deploy_map = {
                'windows': 'DEPLOY_WINDOWS.txt',
                'linux': 'DEPLOY_LINUX.txt',
                'macos': 'DEPLOY_MACOS.txt'
            }

            instruction_file = deploy_map[os_type]

            # Generate instructions with server IP
            with open(f'{template_dir}/{instruction_file}', 'r') as f:
                instructions = f.read()
            instructions = instructions.replace('{{SERVER_IP}}', server_ip)

            # Create package directory
            package_name = f'caldera-sandcat-{os_type}'
            package_dir = f'{session_dir}/{package_name}'
            os.makedirs(package_dir, exist_ok=True)

            # Write deployment instructions
            with open(f'{package_dir}/DEPLOY.txt', 'w') as f:
                f.write(instructions)

            # Create quick reference card
            quick_ref = f"""CALDERA SANDCAT DEPLOYMENT
Server: {server_ip}:7009

Windows: See DEPLOY.txt for PowerShell command
Linux: curl -s -X POST -H "file:sandcat.go" -H "platform:linux" http://{server_ip}:7009/file/download > sandcat && chmod +x sandcat && ./sandcat -server {server_ip}:7009 &
macOS: curl -s -X POST -H "file:sandcat.go" -H "platform:darwin" http://{server_ip}:7009/file/download -o sandcat && chmod +x sandcat && ./sandcat -server {server_ip}:7009 &

Access Caldera: http://{server_ip}:7009
Login: admin / admin

⚠️  RED TEAM TOOL - AUTHORIZED USE ONLY ⚠️
"""
            with open(f'{package_dir}/QUICK_START.txt', 'w') as f:
                f.write(quick_ref)

        # ==================== FLEET (DISABLED - Coming Soon) ====================
        elif agent_type == 'fleet':
            # Temporarily disabled due to HTTP/HTTPS TLS configuration complexity
            return jsonify({'success': False, 'error': 'Fleet agent deployment coming soon - requires additional TLS configuration'}), 400

        elif False and agent_type == 'fleet':  # Disabled code below
            # Validate OS type for Fleet
            valid_os_types = ['windows', 'ubuntu', 'centos', 'macos']
            if os_type not in valid_os_types:
                return jsonify({'success': False, 'error': f'Invalid OS type for Fleet'}), 400

            # Read enrollment secret from file (auto-generated during install)
            secret_file = '/fleet/agents/.enrollment-secret'
            if os.path.exists(secret_file):
                with open(secret_file, 'r') as f:
                    enrollment_secret = f.read().strip()
            else:
                # Fallback default if file doesn't exist
                enrollment_secret = 'cyberblue-fleet-default-secret'
                logger.warning(
                    f"Fleet secret file not found, using default: {enrollment_secret}")

            # Setup for Fleet
            session_id = str(uuid.uuid4())[:8]
            session_dir = f'/fleet/agents/generated/{session_id}'
            os.makedirs(session_dir, exist_ok=True)

            fleet_binary_map = {
                'windows': ('osquery-windows.msi', 'INSTALL_WINDOWS.txt', 'osquery-windows.msi'),
                'ubuntu': ('osquery-ubuntu.deb', 'INSTALL_LINUX_DEB.txt', 'osquery-ubuntu.deb'),
                'centos': ('osquery-centos.rpm', 'INSTALL_LINUX_RPM.txt', 'osquery-centos.rpm'),
                'macos': ('osquery-macos.pkg', 'INSTALL_MACOS.txt', 'osquery-macos.pkg')
            }

            binary_file, instruction_file, target_binary_name = fleet_binary_map[os_type]
            binary_path = f'/fleet/agents/binaries/{binary_file}'
            template_dir = '/fleet/agents/templates'

            if not os.path.exists(binary_path):
                return jsonify({'success': False, 'error': f'Package not found for {os_type}'}), 500

            # Generate fleet-config.flags with embedded secret
            with open(f'{template_dir}/fleet-config.template', 'r') as f:
                fleet_config = f.read()
            fleet_config = fleet_config.replace('{{SERVER_IP}}', server_ip)

            # Also create a secret.txt file with the enrollment secret
            secret_content = enrollment_secret

            # Generate instructions
            with open(f'{template_dir}/{instruction_file}', 'r') as f:
                instructions = f.read()
            instructions = instructions.replace('{{SERVER_IP}}', server_ip)
            instructions = instructions.replace(
                '{{ENROLLMENT_SECRET}}', enrollment_secret)

            # Create package
            package_name = f'fleet-agent-{os_type}'
            package_dir = f'{session_dir}/{package_name}'
            os.makedirs(package_dir, exist_ok=True)

            shutil.copy(binary_path, f'{package_dir}/{target_binary_name}')
            with open(f'{package_dir}/fleet-config.flags', 'w') as f:
                f.write(fleet_config)
            with open(f'{package_dir}/secret.txt', 'w') as f:
                f.write(secret_content)
            with open(f'{package_dir}/INSTALL.txt', 'w') as f:
                f.write(instructions)

        else:
            return jsonify({'success': False, 'error': f'Unknown agent type: {agent_type}'}), 400

        # Create ZIP package
        zip_path = f'{session_dir}/{package_name}.zip'
        with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
            for root, dirs, files in os.walk(package_dir):
                for file in files:
                    file_path = os.path.join(root, file)
                    arcname = os.path.join(
                        package_name, os.path.basename(file))
                    zipf.write(file_path, arcname)

        # Get package size
        package_size_mb = round(os.path.getsize(zip_path) / (1024 * 1024), 2)

        # Fix permissions so file can be downloaded (portal may run as different user)
        try:
            os.chmod(zip_path, 0o644)
            # Also fix directory permissions
            os.chmod(session_dir, 0o755)
        except Exception as perm_error:
            logger.warning(f"Could not fix permissions: {perm_error}")

        # Log the generation
        changelog_manager.add_entry(
            "agent_package_generated",
            f"{agent_type.capitalize()} agent package generated for {os_type} - server IP {server_ip}, session: {session_id}",
            user="portal",
            level="info"
        )

        return jsonify({
            'success': True,
            'session_id': session_id,
            'agent_type': agent_type,
            'server_ip': server_ip,
            'os_type': os_type,
            'package_name': f'{package_name}.zip',
            'package_size_mb': package_size_mb,
            'download_url': f'/api/agents/download/{session_id}/{package_name}.zip',
            'message': f'{agent_type.capitalize()} agent package for {os_type} generated successfully'
        })

    except Exception as e:
        logger.error(f"Error generating agent package: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/agents/download/<session_id>/<filename>')
def download_agent_file(session_id, filename):
    """Download a generated agent file or package"""
    try:
        # Validate session_id format (alphanumeric only)
        import re
        if not re.match(r'^[a-zA-Z0-9-]+$', session_id):
            logger.error(f"Invalid session ID: {session_id}")
            return jsonify({'error': 'Invalid session ID'}), 400

        # Validate filename - allow config files, scripts, and ZIP packages
        import re
        # Allow: .yaml, .ps1, .sh, .zip files with safe characters
        if not re.match(r'^[\w\-\.]+\.(yaml|yml|ps1|sh|zip)$', filename):
            logger.error(f"Invalid filename: {filename}")
            return jsonify({'error': 'Invalid filename'}), 400

        # Prevent directory traversal
        if '..' in filename or '/' in filename:
            logger.error(f"Directory traversal attempt: {filename}")
            return jsonify({'error': 'Invalid filename'}), 400

        # Check all agent directories
        possible_paths = [
            f'/velociraptor/agents/generated/{session_id}/{filename}',
            f'/wazuh/agents/generated/{session_id}/{filename}',
            f'/fleet/agents/generated/{session_id}/{filename}',
            f'/caldera/agents/generated/{session_id}/{filename}'
        ]

        file_path = None
        for path in possible_paths:
            if os.path.exists(path):
                file_path = path
                logger.info(f"Found file at: {path}")
                break

        if not file_path:
            logger.error(
                f"File not found in any location. Session: {session_id}, Filename: {filename}")
            logger.error(f"Checked paths: {possible_paths}")
            return jsonify({'error': 'File not found'}), 404

        from flask import send_file

        # Set appropriate mimetype
        if filename.endswith('.yaml') or filename.endswith('.yml'):
            mimetype = 'text/yaml'
        elif filename.endswith('.ps1'):
            mimetype = 'text/plain'
        elif filename.endswith('.sh'):
            mimetype = 'text/x-shellscript'
        elif filename.endswith('.zip'):
            mimetype = 'application/zip'
        else:
            mimetype = 'application/octet-stream'

        changelog_manager.add_entry(
            "agent_file_downloaded",
            f"Downloaded {filename} from session {session_id}",
            user="portal",
            level="info"
        )

        logger.info(
            f"Sending file: {file_path} ({os.path.getsize(file_path)} bytes)")

        return send_file(
            file_path,
            as_attachment=True,
            download_name=filename,
            mimetype=mimetype
        )

    except Exception as e:
        logger.error(f"Error downloading agent file: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/agents/info')
def get_agent_info():
    """Get information about Velociraptor agent deployment"""
    try:
        # Check if velociraptor is running
        veloci_status = container_monitor.get_tool_container_status().get('velociraptor', {})

        # Check if port 8000 is exposed
        veloci_container_info = container_monitor.get_all_container_status().get(
            'velociraptor', {})
        ports = veloci_container_info.get('ports', '')
        port_8000_exposed = '8000' in ports

        # Check if templates exist
        template_dir = '/velociraptor/agents/templates'
        templates_exist = os.path.exists(template_dir)

        template_files = []
        if templates_exist:
            template_files = os.listdir(template_dir)

        info = {
            'velociraptor_running': veloci_status.get('status') == 'running',
            'port_8000_exposed': port_8000_exposed,
            'templates_available': templates_exist,
            'template_files': template_files,
            'agent_port': 8000,
            'gui_port': 7000,
            'server_ready': veloci_status.get('status') == 'running' and port_8000_exposed,
            'status_message': 'Ready to generate agents' if veloci_status.get('status') == 'running' and port_8000_exposed else 'Velociraptor not ready'
        }

        return jsonify(info)

    except Exception as e:
        logger.error(f"Error getting agent info: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# ARKIME PCAP CAPTURE API
# ============================================================================

@app.route('/api/arkime/capture/start', methods=['POST'])
def start_pcap_capture():
    """Start Arkime PCAP capture for specified duration"""
    try:
        data = request.get_json()
        duration = data.get('duration', 300)  # Default 5 minutes

        # Convert to minutes for script
        duration_min = max(1, duration // 60)

        # Start capture in background
        import threading

        def run_capture():
            try:
                # SIMPLE: Find arkime pcaps directory, run tcpdump, process with Arkime
                logger.info(f"Starting {duration}sec PCAP capture...")

                # Find arkime/pcaps directory from Arkime container's volume mount
                import time
                timestamp = int(time.time())
                pcap_filename = f"portal_{timestamp}.pcap"

                # Get arkime pcaps path from docker volume (RELIABLE!)
                arkime_pcaps_path = None
                try:
                    inspect = subprocess.run(
                        ['docker', 'inspect', 'arkime', '--format',
                         '{{range .Mounts}}{{if eq .Destination "/data/pcap"}}{{.Source}}{{end}}{{end}}'],
                        capture_output=True, text=True, timeout=5
                    )
                    if inspect.stdout.strip():
                        arkime_pcaps_path = inspect.stdout.strip()
                        logger.info(f"✓ Arkime pcaps: {arkime_pcaps_path}")
                except:
                    pass

                if not arkime_pcaps_path:
                    raise Exception(
                        "Could not find Arkime pcaps directory from container")

                # Step 1: Capture with tcpdump
                logger.info(f"Capturing {duration}sec of traffic...")
                subprocess.run(
                    ['docker', 'run', '--rm', '--privileged', '--network', 'host',
                     '-v', f'{arkime_pcaps_path}:/pcaps',
                     'nicolaka/netshoot',
                     'timeout', f'{duration}s', 'tcpdump', '-i', 'any', '-w', f'/pcaps/{pcap_filename}'],
                    timeout=duration + 30
                )

                # Step 2: Process with Arkime
                logger.info("Processing PCAP...")
                subprocess.run(
                    ['docker', 'exec', 'arkime',
                     '/opt/arkime/bin/capture', '-c', '/opt/arkime/etc/config.ini',
                     '-r', f'/data/pcap/{pcap_filename}'],
                    timeout=60
                )

                logger.info(f"✅ PCAP captured and indexed: {pcap_filename}")
            except Exception as e:
                logger.error(f"Arkime capture error: {e}")

        capture_thread = threading.Thread(target=run_capture, daemon=True)
        capture_thread.start()

        changelog_manager.add_entry(
            "arkime_capture_started",
            f"PCAP capture started for {duration_min} minutes",
            user="portal",
            level="info"
        )

        return jsonify({
            'success': True,
            'message': f'Capture started for {duration_min} minutes',
            'duration': duration
        })

    except Exception as e:
        logger.error(f"Error starting PCAP capture: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# ============================================================================
# MISP THREAT INTELLIGENCE API
# ============================================================================

@app.route('/api/misp/search')
def search_misp():
    """Search MISP for IOC (IP, domain, hash, URL, email)"""
    try:
        search_value = request.args.get('value', '').strip()

        if not search_value:
            return jsonify({'success': False, 'error': 'Search value required'}), 400

        # Get MISP API key from database
        misp_api_key_query = subprocess.run(
            ['docker', 'exec', 'misp-core', 'mysql', '-h', 'db', '-u', 'misp', '-pexample', 'misp',
             '-se', "SELECT authkey FROM users WHERE email='admin@admin.test' LIMIT 1;"],
            capture_output=True, text=True, timeout=10
        )

        if misp_api_key_query.returncode != 0:
            return jsonify({'success': False, 'error': 'Could not get MISP API key'}), 500

        misp_api_key = misp_api_key_query.stdout.strip()

        if not misp_api_key:
            return jsonify({'success': False, 'error': 'MISP API key not found'}), 500

        # Search MISP via API (use container name, not localhost)
        search_data = {
            "returnFormat": "json",
            "value": search_value,
            "limit": 50
        }

        import requests
        response = requests.post(
            'https://misp-core/attributes/restSearch',
            headers={
                'Authorization': misp_api_key,
                'Accept': 'application/json',
                'Content-Type': 'application/json'
            },
            json=search_data,
            verify=False,
            timeout=30
        )

        if response.status_code == 200:
            results = response.json()
            attributes = results.get('response', {}).get('Attribute', [])

            return jsonify({
                'success': True,
                'results': attributes,
                'count': len(attributes),
                'search_term': search_value
            })
        else:
            return jsonify({'success': False, 'error': f'MISP returned status {response.status_code}'}), 500

    except Exception as e:
        logger.error(f"Error searching MISP: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/misp/stats')
def get_misp_stats():
    """Get MISP statistics"""
    try:
        # Get stats from MISP database
        event_count_query = subprocess.run(
            ['docker', 'exec', 'misp-core', 'mysql', '-h', 'db', '-u', 'misp', '-pexample', 'misp',
             '-se', "SELECT COUNT(*) FROM events;"],
            capture_output=True, text=True, timeout=10
        )

        attribute_count_query = subprocess.run(
            ['docker', 'exec', 'misp-core', 'mysql', '-h', 'db', '-u', 'misp', '-pexample', 'misp',
             '-se', "SELECT COUNT(*) FROM attributes;"],
            capture_output=True, text=True, timeout=10
        )

        feed_count_query = subprocess.run(
            ['docker', 'exec', 'misp-core', 'mysql', '-h', 'db', '-u', 'misp', '-pexample', 'misp',
             '-se', "SELECT COUNT(*) FROM feeds WHERE enabled=1;"],
            capture_output=True, text=True, timeout=10
        )

        return jsonify({
            'success': True,
            'event_count': int(event_count_query.stdout.strip() or 0),
            'attribute_count': int(attribute_count_query.stdout.strip() or 0),
            'feed_count': int(feed_count_query.stdout.strip() or 0)
        })

    except Exception as e:
        logger.error(f"Error getting MISP stats: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/misp/recent-events')
def get_recent_misp_events():
    """Get recent MISP events"""
    try:
        # Get MISP API key
        misp_api_key_query = subprocess.run(
            ['docker', 'exec', 'misp-core', 'mysql', '-h', 'db', '-u', 'misp', '-pexample', 'misp',
             '-se', "SELECT authkey FROM users WHERE email='admin@admin.test' LIMIT 1;"],
            capture_output=True, text=True, timeout=10
        )

        misp_api_key = misp_api_key_query.stdout.strip()

        if not misp_api_key:
            return jsonify({'success': False, 'error': 'MISP API key not found'}), 500

        # Get recent events via API (use container name)
        import requests
        response = requests.get(
            'https://misp-core/events/index',
            headers={
                'Authorization': misp_api_key,
                'Accept': 'application/json'
            },
            verify=False,
            timeout=30
        )

        if response.status_code == 200:
            events = response.json()
            return jsonify({
                'success': True,
                'events': events[:10] if isinstance(events, list) else []
            })
        else:
            return jsonify({'success': False, 'error': f'MISP returned status {response.status_code}'}), 500

    except Exception as e:
        logger.error(f"Error getting recent MISP events: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/misp/sync-feeds', methods=['POST'])
def sync_misp_feeds():
    """Trigger MISP feed sync"""
    try:
        # Get MISP API key
        misp_api_key_query = subprocess.run(
            ['docker', 'exec', 'misp-core', 'mysql', '-h', 'db', '-u', 'misp', '-pexample', 'misp',
             '-se', "SELECT authkey FROM users WHERE email='admin@admin.test' LIMIT 1;"],
            capture_output=True, text=True, timeout=10
        )

        misp_api_key = misp_api_key_query.stdout.strip()

        if not misp_api_key:
            return jsonify({'success': False, 'error': 'MISP API key not found'}), 500

        # Trigger feed sync (use container name)
        # Run in background since it takes minutes
        import threading

        def sync_feeds_background():
            try:
                import requests
                requests.post(
                    'https://misp-core/feeds/fetchFromAllFeeds',
                    headers={
                        'Authorization': misp_api_key,
                        'Accept': 'application/json'
                    },
                    verify=False,
                    timeout=300  # 5 minutes
                )
                logger.info("MISP feed sync completed")
            except Exception as e:
                logger.error(f"Feed sync error: {e}")

        # Start sync in background
        sync_thread = threading.Thread(
            target=sync_feeds_background, daemon=True)
        sync_thread.start()

        return jsonify({
            'success': True,
            'message': 'Feed sync started in background (may take 2-5 minutes)'
        })

    except Exception as e:
        logger.error(f"Error syncing MISP feeds: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


if __name__ == '__main__':
    logger.info(f"🚀 Starting CyberBlueBox Portal on port {PORT}")
    logger.info(f"📱 Access the portal at: http://localhost:{PORT}")
    logger.info(f"🔧 API endpoints available at: http://localhost:{PORT}/api/")

    try:
        # Log initial startup
        changelog_manager.add_entry(
            "system_startup",
            "CyberBlueBox Portal started successfully with container monitoring",
            level="info"
        )

        # Start container monitoring in a separate thread to avoid blocking
        def start_monitoring_async():
            try:
                container_monitor.start_monitoring()
            except Exception as e:
                logger.error(f"Error starting container monitoring: {e}")

        monitoring_thread = threading.Thread(
            target=start_monitoring_async, daemon=True)
        monitoring_thread.start()

        # Start the Flask app with HTTPS support
        if ENABLE_HTTPS and os.path.exists(SSL_CERT_PATH) and os.path.exists(SSL_KEY_PATH):
            ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ssl_context.load_cert_chain(SSL_CERT_PATH, SSL_KEY_PATH)

            logger.info(f"🔒 Starting HTTPS server on port {HTTPS_PORT}")
            changelog_manager.add_entry(
                "system_startup", f"Portal started with HTTPS on port {HTTPS_PORT}", level="success")
            app.run(host='0.0.0.0', port=HTTPS_PORT, debug=False,
                    threaded=True, ssl_context=ssl_context)
        else:
            logger.warning(
                "⚠️  SSL certificates not found, starting HTTP server")
            logger.info(f"🌐 Starting HTTP server on port {PORT}")
            changelog_manager.add_entry(
                "system_startup", f"Portal started with HTTP on port {PORT}", level="warning")
            app.run(host='0.0.0.0', port=PORT, debug=False, threaded=True)

    except KeyboardInterrupt:
        logger.info("Shutting down CyberBlueBox Portal...")
        changelog_manager.add_entry(
            "system_shutdown", "CyberBlueBox Portal shut down gracefully")
    except Exception as e:
        logger.error(f"Error starting server: {e}")
        changelog_manager.add_entry(
            "system_error", f"Server startup error: {e}", level="error")
        # Don't exit immediately, try to log the error
        time.sleep(5)
        sys.exit(1)
