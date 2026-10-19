#!/bin/bash
# ZIVPN UDP + Admin Panel One-Click Installer
# Port per User System
# If You Change Social Link Panel Errors
# Status = Expire Date only (Online/Expiring/Offline)
# Script Owner By: JueHtet (panel custom)

set -e
export LC_ALL=C

# -----------------------------
# Color variables
C1="\e[38;2;255;182;193m"
C2="\e[38;2;255;105;180m"
C3="\e[38;2;255;20;147m"
BOLD="\e[1m"
NC="\e[0m"
PINK="\e[38;2;255;105;180m"

clear

# Top header
echo -e "${C1}==============================================${NC}"
echo -e "   ${C2}${BOLD}ZIVPN UDP + Admin Panel Auto Installer${NC}"
echo -e "   ${C3}( 🔥 Script Owner By : Jue Htet 🔥 )${NC}"
echo -e "${C1}==============================================${NC}"
echo

# -----------------------------
# Hostname / Domain Setup
# -----------------------------
read -p "Enter Domain or Hostname (e.g. vpn.example.com or press enter to use IP): " SERVER_HOST
[ -z "$SERVER_HOST" ] && SERVER_HOST=""

echo
echo "[0/4] System update & base packages..."
apt-get update -y
apt-get install -y sudo curl wget python3 python3-venv python3-pip sqlite3 ufw conntrack iproute2 iptables openssl

########################################
# 1. INSTALL ZIVPN UDP SERVER
########################################
echo
echo "[1/4] Installing ZIVPN UDP..."
systemctl stop zivpn.service 1>/dev/null 2>/dev/null || true
mkdir -p /etc/zivpn

echo "Downloading UDP Service..."
wget -q https://github.com/zahidbd2/udp-zivpn/releases/download/udp-zivpn_1.4.9/udp-zivpn-linux-amd64 -O /usr/local/bin/zivpn
chmod +x /usr/local/bin/zivpn

echo "Downloading default config..."
wget -q https://raw.githubusercontent.com/zahidbd2/udp-zivpn/main/config.json -O /etc/zivpn/config.json

echo "Generating cert files..."
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
  -subj "/C=US/ST=California/L=Los Angeles/O=Example Corp/OU=IT Department/CN=zivpn" \
  -keyout "/etc/zivpn/zivpn.key" -out "/etc/zivpn/zivpn.crt"

sysctl -w net.core.rmem_max=16777216 1>/dev/null 2>/dev/null || true
sysctl -w net.core.wmem_max=16777216 1>/dev/null 2>/dev/null || true

cat <<EOF > /etc/systemd/system/zivpn.service
[Unit]
Description=zivpn VPN Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/zivpn
ExecStart=/usr/local/bin/zivpn server -c /etc/zivpn/config.json
Restart=no
Environment=ZIVPN_LOG_LEVEL=info
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

echo
echo "ZIVPN UDP Passwords"
read -p "Enter passwords separated by commas, example: pass1,pass2 (Press enter for Default 'zi'): " input_config

if [ -z "$input_config" ]; then
  password_list="\"zi\""
else
  password_list=""
  IFS=',' read -r -a arr <<< "$input_config"
  for p in "${arr[@]}"; do
    p_trim="$(echo "$p" | xargs)"
    [ -z "$p_trim" ] && continue
    password_list="${password_list}\"$p_trim\","
  done
  password_list="${password_list%,}"
  [ -z "$password_list" ] && password_list="\"zi\""
fi

new_config_str="\"config\": [$password_list]"
sed -i -E 's/"config":[[:space:]]*\[[^]]*\]/'"$new_config_str"'/g' /etc/zivpn/config.json

systemctl daemon-reload
systemctl enable zivpn.service
systemctl start zivpn.service

DEV=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1 || true)
if [ -n "$DEV" ]; then
  iptables -t nat -A PREROUTING -i "$DEV" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 || true
fi

# Firewall rules
ufw allow 6000:19999/udp || true
ufw allow 5667/udp || true
ufw allow 8989/tcp || true

# Clean quota chain
iptables -t raw -D PREROUTING -p udp --dport 6000:19999 -j ZIVPN_QUOTA 2>/dev/null || true
iptables -t raw -F ZIVPN_QUOTA 2>/dev/null || true
iptables -t raw -X ZIVPN_QUOTA 2>/dev/null || true
rm -f zi.* 1>/dev/null 2>/dev/null || true

echo
echo "[+] ZIVPN UDP Installed."

########################################
# 2. ADMIN LOGIN & CONFIG SETUP
########################################
echo
echo "[2/4] Configure Admin Panel Login..."
mkdir -p /etc/zivpn-admin

read -p "Set Admin Panel username (default: admin): " ADMIN_USER
[ -z "$ADMIN_USER" ] && ADMIN_USER="admin"

read -p "Set Admin Panel password (default: admin123): " ADMIN_PASS
[ -z "$ADMIN_PASS" ] && ADMIN_PASS="admin123"

ADMIN_USER_JSON=$(printf '%s' "$ADMIN_USER" | sed 's/\"/\\\"/g')
ADMIN_PASS_JSON=$(printf '%s' "$ADMIN_PASS" | sed 's/\"/\\\"/g')
HOST_JSON=$(printf '%s' "$SERVER_HOST" | sed 's/\"/\\\"/g')

cat <<EOF > /etc/zivpn-admin/admin.json
{
  "username": "$ADMIN_USER_JSON",
  "password": "$ADMIN_PASS_JSON",
  "domain": "$HOST_JSON"
}
EOF
chmod 600 /etc/zivpn-admin/admin.json
chown root:root /etc/zivpn-admin/admin.json

cat <<'EOF' > /etc/zivpn-admin/social.json
{
  "telegram": "https://t.me/Pussy1990",
  "facebook": "https://www.facebook.com/juehtet2025",
  "messenger": "https://m.me/juehtet2025",
  "icons": {
    "telegram": "https://raw.githubusercontent.com/JVPNSHOP/Admin-Zivpn/main/image/t.png",
    "facebook": "https://raw.githubusercontent.com/JVPNSHOP/Admin-Zivpn/main/image/f.png",
    "messenger": "https://raw.githubusercontent.com/JVPNSHOP/Admin-Zivpn/main/image/m.png"
  }
}
EOF
chmod 600 /etc/zivpn-admin/social.json
chown root:root /etc/zivpn-admin/social.json

########################################
# 3. ADMIN PANEL BACKEND (server.py)
########################################
echo
echo "[3/4] Installing ZIVPN Admin Panel (Web UI Backend)..."
apt-get install -y python3-venv python3-pip 1>/dev/null 2>/dev/null || true

mkdir -p /usr/local/zivpn-admin/panel
mkdir -p /var/lib/zivpn-admin

if [ ! -d "/usr/local/zivpn-admin/venv" ]; then
    python3 -m venv /usr/local/zivpn-admin/venv
fi

/usr/local/zivpn-admin/venv/bin/pip install --upgrade pip 1>/dev/null 2>/dev/null
/usr/local/zivpn-admin/venv/bin/pip install flask 1>/dev/null 2>/dev/null

cat << 'EOF' > /usr/local/zivpn-admin/server.py
#!/usr/bin/env python3
import os
import json
import sqlite3
import datetime
import subprocess
from functools import wraps
from flask import Flask, request, jsonify, send_from_directory, redirect, session, abort

DB_PATH = "/var/lib/zivpn-admin/zivpn.db"
CONFIG_PATH = "/etc/zivpn/config.json"
ADMIN_FILE = "/etc/zivpn-admin/admin.json"
SOCIAL_FILE = "/etc/zivpn-admin/social.json"
LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = 8989
PORT_MIN = 6001
PORT_MAX = 19999

app = Flask(__name__, static_folder="panel", static_url_path="/panel")
app.secret_key = "zivpn_super_secret_key_change_me"

def get_db():
    conn = sqlite3.connect(DB_PATH, timeout=30, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    cur = conn.cursor()
    cur.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE,
            password TEXT NOT NULL,
            created_at TEXT NOT NULL,
            expire_at TEXT NOT NULL,
            udp_port INTEGER UNIQUE
        )
        """
    )
    conn.commit()
    conn.close()

def get_admin_creds():
    try:
        with open(ADMIN_FILE, "r") as f:
            data = json.load(f)
        return data.get("username", "admin"), data.get("password", "admin123"), data.get("domain", "")
    except Exception:
        return "admin", "admin123", ""

def login_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if not session.get("admin_logged_in"):
            return redirect("/login")
        return f(*args, **kwargs)
    return wrapper

def get_server_ip():
    try:
        cmd = "ip -4 route get 1.1.1.1 | awk '{print $7}' | head -1"
        ip = subprocess.check_output(["bash", "-lc", cmd]).decode().strip()
        if ip: return ip
    except Exception:
        pass
    try:
        cmd = "hostname -I | awk '{print $1}'"
        ip = subprocess.check_output(["bash", "-lc", cmd]).decode().strip()
        if ip: return ip
    except Exception:
        pass
    return "127.0.0.1"

def get_server_stats():
    cpu_percent = None
    mem_total_gb = None
    mem_used_percent = None
    disk_total_gb = None
    disk_used_percent = None
    try:
        load1, _, _ = os.getloadavg()
        cores = os.cpu_count() or 1
        cpu_percent = min(100.0, round(load1 / cores * 100.0, 1))
    except Exception:
        pass
    try:
        meminfo = {}
        with open("/proc/meminfo") as f:
            for line in f:
                parts = line.split(":")
                if len(parts) < 2: continue
                key = parts[0].strip()
                val = parts[1].strip().split()[0]
                meminfo[key] = float(val)
        total_kb = meminfo.get("MemTotal", 0.0)
        avail_kb = meminfo.get("MemAvailable", 0.0)
        if total_kb > 0:
            mem_total_gb = round(total_kb / (1024*1024), 1)
            used_kb = total_kb - avail_kb
            mem_used_percent = round(used_kb / total_kb * 100.0, 1)
    except Exception:
        pass
    try:
        st = os.statvfs("/")
        total = st.f_frsize * st.f_blocks
        free = st.f_frsize * st.f_bavail
        if total > 0:
            disk_total_gb = round(total / (1024**3), 1)
            disk_used_percent = round((total - free) / total * 100.0, 1)
    except Exception:
        pass
    return {
        "cpu_percent": cpu_percent,
        "mem_total_gb": mem_total_gb,
        "mem_used_percent": mem_used_percent,
        "disk_total_gb": disk_total_gb,
        "disk_used_percent": disk_used_percent,
    }

def user_to_dict(row):
    try:
        expire_at = datetime.datetime.fromisoformat(row["expire_at"])
    except Exception:
        expire_at = datetime.datetime.utcnow()
    try:
        created_at = datetime.datetime.fromisoformat(row["created_at"])
    except Exception:
        created_at = datetime.datetime.utcnow()
    
    now = datetime.datetime.utcnow()
    days_left = (expire_at.date() - now.date()).days
    if days_left < 0:
        days_left = 0
    if expire_at < now:
        status = "Offline"
    elif days_left <= 3:
        status = "Expiring"
    else:
        status = "Online"

    return {
        "id": row["id"],
        "username": row["username"],
        "password": row["password"],
        "created_at": created_at.strftime("%Y-%m-%d"),
        "expire_at": expire_at.strftime("%Y-%m-%d"),
        "day_left": days_left,
        "status": status,
        "udp_port": row["udp_port"],
    }

def sync_config_with_db():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT password, expire_at FROM users")
        rows = cur.fetchall()
        conn.close()

        passwords = []
        now = datetime.datetime.utcnow()
        for r in rows:
            try:
                expire_at = datetime.datetime.fromisoformat(r["expire_at"])
            except Exception:
                continue
            if expire_at >= now and r["password"] not in passwords:
                passwords.append(r["password"])

        if not os.path.exists(CONFIG_PATH):
            return

        with open(CONFIG_PATH, "r") as f:
            data = json.load(f)

        auth = data.get("auth", {})
        auth["config"] = passwords if passwords else ["zi"]
        data["auth"] = auth

        with open(CONFIG_PATH, "w") as f:
            json.dump(data, f)

        subprocess.run(["systemctl", "restart", "zivpn.service"], check=False)
    except Exception as e:
        print("sync_config_with_db error:", e)

def allocate_udp_port():
    conn = get_db()
    cur = conn.cursor()
    try:
        cur.execute("SELECT udp_port FROM users WHERE udp_port IS NOT NULL")
        rows = cur.fetchall()
    except sqlite3.OperationalError as e:
        print("allocate_udp_port warning:", e)
        rows = []
    conn.close()

    used = {r["udp_port"] for r in rows if r["udp_port"] is not None}
    for p in range(PORT_MIN, PORT_MAX + 1):
        if p not in used:
            return p
    return None

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        return send_from_directory("panel", "login.html")
    username = (request.form.get("username") or "").strip()
    password = (request.form.get("password") or "").strip()
    admin_user, admin_pass, _ = get_admin_creds()
    if username == admin_user and password == admin_pass:
        session["admin_logged_in"] = True
        return redirect("/")
    return send_from_directory("panel", "login.html")

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/login")

@app.route("/")
@login_required
def index():
    return send_from_directory("panel", "index.html")

@app.route("/api/server", methods=["GET"])
@login_required
def api_server_info():
    ip = get_server_ip()
    _, _, domain = get_admin_creds()
    domain_clean = (domain or "").strip()
    stats = get_server_stats()
    return jsonify({
        "ip": ip,
        "domain": domain_clean or ip,
        "hostname": domain_clean,
        "panel_port": LISTEN_PORT,
        "udp_port": 5667,
        "cpu_percent": stats["cpu_percent"],
        "mem_total_gb": stats["mem_total_gb"],
        "mem_used_percent": stats["mem_used_percent"],
        "disk_total_gb": stats["disk_total_gb"],
        "disk_used_percent": stats["disk_used_percent"],
    })

@app.route("/api/social", methods=["GET"])
@login_required
def api_social():
    try:
        if not os.path.exists(SOCIAL_FILE):
            return jsonify({"telegram": "", "facebook": "", "messenger": "", "icons": {}})
        with open(SOCIAL_FILE, "r") as f:
            data = json.load(f)
        result = {
            "telegram": data.get("telegram", ""),
            "facebook": data.get("facebook", ""),
            "messenger": data.get("messenger", ""),
            "icons": data.get("icons", {})
        }
        return jsonify(result)
    except Exception as e:
        return jsonify({"telegram": "", "facebook": "", "messenger": "", "icons": {}})

@app.route("/api/users", methods=["GET"])
@login_required
def api_list_users():
    conn = get_db()
    cur = conn.cursor()
    cur.execute("SELECT * FROM users ORDER BY id DESC")
    rows = cur.fetchall()
    conn.close()
    users = [user_to_dict(r) for r in rows]
    total = len(users)
    online = sum(1 for u in users if u["status"] in ("Online", "Expiring"))
    offline = sum(1 for u in users if u["status"] == "Offline")
    return jsonify({
        "total": total,
        "online": online,
        "offline": offline,
        "users": users
    })

@app.route("/api/users", methods=["POST"])
@login_required
def api_create_user():
    try:
        data = request.get_json(silent=True) or request.form
        username = (data.get("username") or "").strip()
        password = (data.get("password") or "").strip()
        expire_date_str = (data.get("expire_date") or "").strip()

        if not username or not password:
            return jsonify({"error": "username and password required"}), 400

        udp_port = allocate_udp_port()
        if udp_port is None:
            return jsonify({"error": "no free UDP port available"}), 400

        now = datetime.datetime.utcnow()
        created_at = now.isoformat()

        if expire_date_str:
            try:
                expire_date = datetime.datetime.strptime(expire_date_str, "%Y-%m-%d")
            except ValueError:
                expire_date = now + datetime.timedelta(days=30)
        else:
            expire_date = now + datetime.timedelta(days=30)

        expire_at = expire_date.replace(hour=0, minute=0, second=0, microsecond=0).isoformat()

        conn = get_db()
        cur = conn.cursor()
        try:
            cur.execute(
                "INSERT INTO users (username, password, created_at, expire_at, udp_port) "
                "VALUES (?, ?, ?, ?, ?)",
                (username, password, created_at, expire_at, udp_port),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            conn.close()
            return jsonify({"error": "username already exists"}), 400
        except sqlite3.OperationalError as e:
            conn.close()
            return jsonify({"error": "database error: " + str(e)}), 500
        conn.close()

        sync_config_with_db()
        return jsonify({"success": True, "udp_port": udp_port})
    except Exception as e:
        print("api_create_user unexpected error:", e)
        return jsonify({"error": "internal error: " + str(e)}), 500

@app.route("/api/users/<int:user_id>", methods=["DELETE"])
@login_required
def api_delete_user(user_id):
    conn = get_db()
    cur = conn.cursor()
    cur.execute("DELETE FROM users WHERE id = ?", (user_id,))
    conn.commit()
    conn.close()
    sync_config_with_db()
    return jsonify({"success": True})

@app.route("/api/users/<int:user_id>", methods=["PUT"])
@login_required
def api_update_user(user_id):
    data = request.get_json(silent=True) or request.form
    password = (data.get("password") or "").strip()
    expire_date_str = (data.get("expire_date") or "").strip()

    fields = []
    params = []

    if password:
        fields.append("password = ?")
        params.append(password)

    if expire_date_str:
        try:
            expire_date = datetime.datetime.strptime(expire_date_str, "%Y-%m-%d")
            expire_at = expire_date.replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
            fields.append("expire_at = ?")
            params.append(expire_at)
        except ValueError:
            pass

    if not fields:
        return jsonify({"error": "nothing to update"}), 400

    params.append(user_id)
    conn = get_db()
    cur = conn.cursor()
    cur.execute(f"UPDATE users SET {', '.join(fields)} WHERE id = ?", params)
    conn.commit()
    conn.close()
    sync_config_with_db()
    return jsonify({"success": True})

@app.route("/api/admin", methods=["POST"])
@login_required
def api_update_admin():
    data = request.get_json(silent=True) or {}
    old_password = (data.get("old_password") or "").strip()
    new_username = (data.get("new_username") or "").strip()
    new_password = (data.get("new_password") or "").strip()

    current_user, current_pass, current_domain = get_admin_creds()
    if old_password != current_pass:
        return jsonify({"error": "Old password incorrect"}), 400

    if not new_username: new_username = current_user
    if not new_password: new_password = current_pass

    try:
        with open(ADMIN_FILE, "w") as f:
            json.dump({"username": new_username, "password": new_password, "domain": current_domain}, f)
        os.chmod(ADMIN_FILE, 0o600)
        return jsonify({"success": True, "username": new_username})
    except Exception as e:
        return jsonify({"error": str(e)}, 500)

# ==========================================================
# BACKUP / RESTORE ENDPOINTS
# ==========================================================
@app.route("/api/backup", methods=["GET"])
@login_required
def api_backup():
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT username, password, created_at, expire_at, udp_port FROM users ORDER BY id ASC")
        rows = cur.fetchall()
        conn.close()

        users = []
        for r in rows:
            users.append({
                "username": r["username"],
                "password": r["password"],
                "created_at": r["created_at"],
                "expire_at": r["expire_at"],
                "udp_port": r["udp_port"],
            })

        admin_data = {}
        try:
            with open(ADMIN_FILE, "r") as f:
                admin_data = json.load(f)
        except Exception:
            admin_data = {}

        social_data = {}
        try:
            with open(SOCIAL_FILE, "r") as f:
                social_data = json.load(f)
        except Exception:
            social_data = {}

        backup_payload = {
            "version": 1,
            "exported_at": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "users": users,
            "admin": admin_data,
            "social": social_data,
        }

        filename = "zivpn_backup_" + datetime.datetime.utcnow().strftime("%Y%m%d_%H%M%S") + ".json"

        response = app.response_class(
            response=json.dumps(backup_payload, indent=2),
            status=200,
            mimetype="application/json",
        )
        response.headers["Content-Disposition"] = 'attachment; filename="' + filename + '"'
        response.headers["Cache-Control"] = "no-store"
        return response
    except Exception as e:
        return jsonify({"error": "backup failed: " + str(e)}), 500


@app.route("/api/restore", methods=["POST"])
@login_required
def api_restore():
    try:
        data = request.get_json(silent=True)
        if not data:
            return jsonify({"error": "No backup data provided"}), 400

        users = data.get("users")
        if not isinstance(users, list):
            return jsonify({"error": "Invalid backup: 'users' must be a list"}), 400

        # Restore users: delete all then insert from backup
        conn = get_db()
        cur = conn.cursor()
        cur.execute("DELETE FROM users")

        restored = 0
        skipped = 0
        for u in users:
            if not isinstance(u, dict):
                skipped += 1
                continue
            username = (u.get("username") or "").strip()
            password = (u.get("password") or "").strip()
            if not username or not password:
                skipped += 1
                continue

            created_at = u.get("created_at") or datetime.datetime.utcnow().isoformat()
            expire_at = u.get("expire_at") or (
                datetime.datetime.utcnow() + datetime.timedelta(days=30)
            ).isoformat()
            udp_port = u.get("udp_port")

            try:
                cur.execute(
                    "INSERT INTO users (username, password, created_at, expire_at, udp_port) "
                    "VALUES (?, ?, ?, ?, ?)",
                    (username, password, created_at, expire_at, udp_port),
                )
                restored += 1
            except sqlite3.IntegrityError:
                skipped += 1
                continue

        conn.commit()
        conn.close()

        # Restore admin credentials if provided
        admin_data = data.get("admin")
        if isinstance(admin_data, dict) and admin_data.get("username") and admin_data.get("password"):
            try:
                with open(ADMIN_FILE, "w") as f:
                    json.dump(admin_data, f)
                os.chmod(ADMIN_FILE, 0o600)
            except Exception as e:
                print("restore admin error:", e)

        # Restore social links if provided
        social_data = data.get("social")
        if isinstance(social_data, dict):
            try:
                with open(SOCIAL_FILE, "w") as f:
                    json.dump(social_data, f, indent=2)
                os.chmod(SOCIAL_FILE, 0o600)
            except Exception as e:
                print("restore social error:", e)

        # Re-sync zivpn UDP passwords from restored users
        sync_config_with_db()

        return jsonify({
            "success": True,
            "restored_users": restored,
            "skipped": skipped,
            "total_in_backup": len(users),
        })
    except Exception as e:
        return jsonify({"error": "restore failed: " + str(e)}), 500

if __name__ == "__main__":
    init_db()
    app.run(host=LISTEN_HOST, port=LISTEN_PORT)
EOF

chmod +x /usr/local/zivpn-admin/server.py

########################################
# 4. FRONTEND UI & EDIT MODAL
########################################
echo
echo "[4/4] Installing Panel UI..."

# ---- login.html ----
cat << 'EOF' > /usr/local/zivpn-admin/panel/login.html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>ZIVPN Admin Login</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root { font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body {
      margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
      background: radial-gradient(circle at top, #1f2937 0, #020617 50%, #000 100%); color: #e5e7eb;
    }
    .card {
      background: rgba(15,23,42,0.95); border-radius: 18px; padding: 24px 22px; width: 320px;
      box-shadow: 0 18px 40px rgba(0,0,0,0.7); border: 1px solid rgba(148,163,184,0.35); backdrop-filter: blur(14px);
    }
    h1 { margin: 0 0 4px; font-size: 1.4rem; display: flex; align-items: center; gap: 8px; }
    .logo { width: 30px; height: 30px; border-radius: 999px; overflow: hidden; display: inline-flex; align-items: center; justify-content: center; }
    .logo img { width: 100%; height: 100%; object-fit: cover; }
    .subtitle { font-size: 0.8rem; color: #9ca3af; margin-bottom: 14px; }
    label { display: block; font-size: 0.75rem; color: #9ca3af; margin-bottom: 4px; }
    input {
      width: 100%; background: rgba(15,23,42,0.95); border-radius: 10px; border: 1px solid rgba(148,163,184,0.5);
      padding: 7px 10px; color: #e5e7eb; font-size: 0.85rem; margin-bottom: 10px; box-sizing: border-box;
    }
    .remember-row { display: flex; align-items: center; gap: 6px; font-size: 0.75rem; color: #9ca3af; margin-bottom: 8px; }
    .remember-row input { width: auto; margin: 0; }
    button {
      width: 100%; margin-top: 4px; padding: 8px 10px; border-radius: 999px; border: none; cursor: pointer;
      background: linear-gradient(135deg,#22c55e,#0ea5e9,#a855f7); background-size: 200% 200%; color: #020617;
      font-weight: 600; font-size: 0.9rem; box-shadow: 0 14px 28px rgba(0,0,0,0.7); animation: loginBtn 4s ease-in-out infinite;
    }
    @keyframes loginBtn { 0%,100%{background-position:0% 50%;} 50%{background-position:100% 50%;} }
    .muted { margin-top: 8px; font-size: 0.75rem; color: #9ca3af; text-align: center; }
  </style>
</head>
<body>
  <div class="card">
    <h1>
      <span class="logo"><img src="https://raw.githubusercontent.com/JVPNSHOP/Admin-Zivpn/main/image/z.png" alt="ZIVPN"></span>
      <span>Admin Login</span>
    </h1>
    <div class="subtitle">Enter the admin username and password from installer output.</div>
    <form method="post" id="login-form">
      <label>Username</label>
      <input name="username" autocomplete="off" required>
      <label>Password</label>
      <input name="password" autocomplete="off" required>
      <label class="remember-row">
        <input type="checkbox" id="rememberMe">
        <span>Save login</span>
      </label>
      <button type="submit">Login</button>
    </form>
    <div class="muted">Protected ZIVPN Admin Panel</div>
  </div>
  <script>
    const userInput = document.querySelector('input[name="username"]');
    const passInput = document.querySelector('input[name="password"]');
    const remember = document.getElementById('rememberMe');
    const form = document.getElementById('login-form');

    window.addEventListener('DOMContentLoaded', () => {
      try {
        const saved = JSON.parse(localStorage.getItem('zivpn_login_save') || 'null');
        if (saved) {
          if (saved.username) userInput.value = saved.username;
          if (saved.password) passInput.value = saved.password;
          remember.checked = true;
        }
      } catch(e) {}
    });

    form.addEventListener('submit', () => {
      if (remember.checked) {
        const payload = { username: userInput.value || "", password: passInput.value || "" };
        localStorage.setItem('zivpn_login_save', JSON.stringify(payload));
      } else {
        localStorage.removeItem('zivpn_login_save');
      }
    });
  </script>
</body>
</html>
EOF

# ---- index.html ----
cat << 'EOF' > /usr/local/zivpn-admin/panel/index.html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>ZIVPN Admin Panel</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root { font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body {
      margin: 0; padding: 0; background: radial-gradient(circle at top, #1f2937 0, #020617 45%, #000 100%);
      color: #e5e7eb; min-height: 100vh; transition: background 0.25s ease, color 0.25s ease;
    }
    body.light-mode { background: radial-gradient(circle at top, #e5e7eb 0, #f9fafb 45%, #e5e7eb 100%); color: #0f172a; }
    .container { max-width: 1100px; margin: 0 auto; padding: 24px 14px 40px; }
    .card {
      background: rgba(15,23,42,0.95); border-radius: 18px; padding: 20px 18px; box-shadow: 0 18px 40px rgba(0,0,0,0.7);
      border: 1px solid rgba(148,163,184,0.35); backdrop-filter: blur(14px); transition: background 0.25s ease, border-color 0.25s ease;
    }
    body.light-mode .card { background: #f9fafb; border-color: #d1d5db; }
    h1 { font-size: 1.6rem; margin: 0 0 10px; display: flex; align-items: center; gap: 8px; }
    .logo { display: inline-flex; width: 34px; height: 34px; border-radius: 999px; overflow: hidden; align-items: center; justify-content: center; box-shadow: 0 0 18px rgba(34,197,94,0.7); }
    .logo img { width: 100%; height: 100%; object-fit: cover; }
    .top-row { display: flex; flex-wrap: wrap; gap: 12px; align-items: center; margin-bottom: 14px; }
    .vps-box {
      padding: 10px 12px; border-radius: 14px; background: rgba(15,23,42,0.95); border: 1px solid rgba(148,163,184,0.45);
      flex: 1 1 100%; width: 100%; box-sizing: border-box; transition: background 0.25s ease, border-color 0.25s ease;
    }
    body.light-mode .vps-box { background: #eef2ff; border-color: #c7d2fe; }
    .vps-label { font-size: 0.7rem; text-transform: uppercase; letter-spacing: .09em; color: #9ca3af; margin-bottom: 4px; }
    body.light-mode .vps-label { color: #6b7280; }
    .vps-value { font-size: 1rem; font-weight: 600; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
    .muted { font-size: 0.75rem; color: #9ca3af; }
    body.light-mode .muted { color: #6b7280; }
    .stat-row { display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 16px; }
    .stat-chip {
      flex: 1 1 80px; min-width: 90px; border-radius: 12px; padding: 8px 10px; background: rgba(15,23,42,0.95);
      border: 1px solid rgba(148,163,184,0.45); font-size: 0.8rem; transition: background 0.25s ease, border-color 0.25s ease;
      width: 100%; box-sizing: border-box;
    }
    body.light-mode .stat-chip { background: #e5f0ff; border-color: #bfdbfe; }
    .stat-label { color:#9ca3af; margin-bottom:2px; display:flex;align-items:center;gap:6px;}
    body.light-mode .stat-label { color:#6b7280; }
    .stat-value { font-size:0.9rem;font-weight:600;}
    .stat-dot { width:10px; height:10px; border-radius:999px; display:inline-block; }
    .stat-dot-online { background: radial-gradient(circle at 30% 30%, #bbf7d0 0, #22c55e 40%, #065f46 100%); box-shadow:0 0 8px rgba(34,197,94,0.9),0 0 16px rgba(34,197,94,0.6); animation:pulseGreen 1.4s ease-in-out infinite; }
    .stat-dot-offline { background: radial-gradient(circle at 30% 30%, #fecaca 0, #ef4444 40%, #7f1d1d 100%); box-shadow:0 0 8px rgba(248,113,113,0.9),0 0 16px rgba(248,113,113,0.6); animation:pulseRed 1.4s ease-in-out infinite; }
    .pill { font-size: 0.7rem; padding: 3px 8px; border-radius: 999px; border: 1px solid rgba(148,163,184,0.5); background: rgba(15,23,42,0.95); }
    .pill-blue { border-color: rgba(34,197,94,0.9); color: #bbf7d0; background: rgba(22,163,74,0.18); }
    body.light-mode .pill-blue { background:#bbf7d0; border-color:#22c55e; color:#166534; }
    .form-row { display: flex; flex-direction: column; gap: 10px; margin-bottom: 10px; align-items: stretch; width: 100%; box-sizing: border-box; }
    .input-wrap { display: flex; flex-direction: column; gap: 4px; }
    .input-wrap span.icon { font-size: 0.8rem; opacity: 0.9; color: #9ca3af; }
    body.light-mode .input-wrap span.icon { color: #6b7280; }
    .input-wrap input {
      width: 100%; padding: 7px 9px; border-radius: 10px; border: 1px solid rgba(148,163,184,0.6);
      background: rgba(15,23,42,0.95); color: #e5e7eb; font-size: 0.85rem; transition: background 0.25s ease, color 0.25s ease, border-color 0.25s ease; box-sizing: border-box;
    }
    body.light-mode .input-wrap input { background: #ffffff; color: #0f172a; border-color: #cbd5f5; }
    .btn {
      border-radius: 999px; border: none; padding: 7px 14px; font-size: 0.85rem; display: inline-flex;
      align-items: center; gap: 6px; cursor: pointer; background: linear-gradient(135deg,#22c55e,#0ea5e9,#a855f7);
      background-size: 200% 200%; color: #020617; font-weight: 600; box-shadow: 0 14px 30px rgba(0,0,0,0.7);
      white-space: nowrap; animation: btnShift 4s ease-in-out infinite;
    }
    @keyframes btnShift{0%,100%{background-position:0% 50%;}50%{background-position:100% 50%;}}
    .btn-sm { padding: 4px 9px; font-size: 0.78rem; box-shadow: none; }
    .btn-ghost { background: transparent; border: 1px solid rgba(148,163,184,0.6); color: inherit; animation:none; background-size:auto; }
    .btn-danger { background: rgba(239,68,68,0.12); border: 1px solid rgba(248,113,113,0.8); color: #fecaca; box-shadow:none; animation:none; }
    body.light-mode .btn-danger { background: #fee2e2; color: #b91c1c; }
    .data-row {
      display: flex; gap: 8px; flex-wrap: wrap; align-items: center;
      margin: 0 0 14px; padding: 10px; border-radius: 12px;
      background: rgba(15,23,42,0.6); border: 1px dashed rgba(148,163,184,0.45);
    }
    body.light-mode .data-row { background: #f1f5f9; border-color: #cbd5e1; }
    .data-row .label-text { font-size: 0.75rem; color: #9ca3af; margin-right: auto; }
    body.light-mode .data-row .label-text { color: #64748b; }
    .search-row {
      display: flex; gap: 8px; align-items: center; margin: 4px 0 12px; flex-wrap: wrap;
    }
    .search-box {
      flex: 1 1 220px; display: flex; align-items: center; gap: 6px;
      background: rgba(15,23,42,0.95); border: 1px solid rgba(148,163,184,0.55);
      border-radius: 999px; padding: 5px 12px; transition: background 0.25s ease, border-color 0.25s ease;
    }
    body.light-mode .search-box { background: #ffffff; border-color: #cbd5f5; }
    .search-box:focus-within { border-color: #22c55e; box-shadow: 0 0 0 2px rgba(34,197,94,0.25); }
    .search-box span { font-size: 0.85rem; color: #9ca3af; }
    body.light-mode .search-box span { color: #6b7280; }
    .search-box input {
      flex: 1; border: none; outline: none; background: transparent; color: inherit;
      font-size: 0.85rem; padding: 4px 2px;
    }
    body.light-mode .search-box input { color: #0f172a; }
    .search-clear {
      border: none; background: transparent; cursor: pointer; color: #9ca3af; font-size: 0.9rem; padding: 0 4px;
    }
    .search-clear:hover { color: #ef4444; }
    .search-count { font-size: 0.75rem; color: #9ca3af; white-space: nowrap; }
    body.light-mode .search-count { color: #6b7280; }
    .users-grid { display: grid; grid-template-columns: repeat(auto-fill,minmax(260px,1fr)); gap: 10px; margin-top: 6px; }
    .user-card { background: rgba(15,23,42,0.98); border-radius: 14px; border: 1px solid rgba(55,65,81,0.9); padding: 10px 10px; font-size: 0.78rem; transition: background 0.25s ease, border-color 0.25s ease; }
    body.light-mode .user-card { background: #ffffff; border-color: #d1d5db; }
    .user-header { display:flex; justify-content:space-between; align-items:center; margin-bottom:4px; }
    .user-title { font-weight:600; display:flex; align-items:center; gap:6px; font-size:0.85rem; }
    .profile-avatar {
      width: 24px; height: 24px; border-radius: 50%;
      display: inline-flex; align-items: center; justify-content: center;
      font-size: 0.72rem; font-weight: 700; color: #fff;
      text-transform: uppercase; flex-shrink: 0;
      box-shadow: 0 2px 8px rgba(0,0,0,0.4);
      text-shadow: 0 1px 2px rgba(0,0,0,0.3);
      letter-spacing: 0.02em;
    }
    .badge-port { font-size:0.7rem; border-radius:999px; padding:2px 7px; border:1px solid rgba(34,197,94,0.9); color:#bbf7d0; background:rgba(22,163,74,0.18); }
    body.light-mode .badge-port { background:#bbf7d0; border-color:#22c55e; color:#166534; }
    .field-row {display:flex;justify-content:space-between;gap:6px;margin:1px 0;}
    .field-label {color:#9ca3af;}
    body.light-mode .field-label {color:#6b7280;}
    .field-value {
      font-weight:500; display:flex; align-items:center; gap:5px;
      background: linear-gradient(120deg,#22c55e,#0ea5e9,#a855f7); background-size:200% 200%;
      -webkit-background-clip:text; color: transparent; animation:textFlow 5s ease-in-out infinite;
    }
    @keyframes textFlow{ 0%,100%{background-position:0% 50%;} 50%{background-position:100% 50%;} }
    .status-dot { width:9px; height:9px; border-radius:999px; display:inline-block; margin-right:4px; }
    .status-online { background: radial-gradient(circle at 30% 30%, #bbf7d0 0, #22c55e 40%, #065f46 100%); box-shadow: 0 0 8px rgba(34,197,94,0.9), 0 0 16px rgba(34,197,94,0.6); animation:pulseGreen 1.4s ease-in-out infinite; }
    .status-warning { background: radial-gradient(circle at 30% 30%, #fef9c3 0, #eab308 40%, #854d0e 100%); box-shadow:0 0 8px rgba(234,179,8,0.9),0 0 16px rgba(234,179,8,0.6); animation:pulseYellow 1.4s ease-in-out infinite; }
    .status-offline { background: radial-gradient(circle at 30% 30%, #fecaca 0, #ef4444 40%, #7f1d1d 100%); box-shadow:0 0 8px rgba(248,113,113,0.9),0 0 16px rgba(248,113,113,0.6); animation:pulseRed 1.4s ease-in-out infinite; }
    @keyframes pulseGreen { 0%,100% { transform: scale(1); opacity:1;} 50% { transform: scale(1.4); opacity:0.6;} }
    @keyframes pulseYellow { 0%,100% { transform: scale(1); opacity:1;} 50% { transform: scale(1.4); opacity:0.6;} }
    @keyframes pulseRed { 0%,100% { transform: scale(1); opacity:1;} 50% { transform: scale(1.4); opacity:0.6;} }
    .actions {display:flex;gap:4px;margin-top:6px;}
    .logout-fab {
      position: fixed; top: 14px; right: 14px; width: 36px; height: 36px; border-radius: 999px;
      display: flex; align-items: center; justify-content: center; background: linear-gradient(135deg,#f97316,#ef4444);
      color: #0b1120; text-decoration: none; font-size: 0.95rem; box-shadow: 0 14px 30px rgba(0,0,0,0.85); border: 1px solid rgba(248,250,252,0.7); z-index: 50;
    }
    .theme-fab {
      position: fixed; top: 60px; right: 14px; width: 36px; height: 36px; border-radius: 999px;
      display: flex; align-items: center; justify-content: center; background: linear-gradient(135deg,#0ea5e9,#6366f1);
      color: #f9fafb; text-decoration: none; font-size: 0.95rem; box-shadow: 0 12px 28px rgba(0,0,0,0.7); border: 1px solid rgba(248,250,252,0.7); z-index: 50; cursor: pointer;
    }
    .settings-fab {
      position: fixed; top: 106px; right: 14px; width: 36px; height: 36px; border-radius: 999px;
      display: flex; align-items: center; justify-content: center; background: linear-gradient(135deg,#22c55e,#14b8a6);
      color: #0b1120; text-decoration: none; font-size: 0.95rem; box-shadow: 0 12px 28px rgba(0,0,0,0.7); border: 1px solid rgba(248,250,252,0.7); z-index: 50; cursor: pointer;
    }

    /* ===== Copy button (SVG, no emoji) ===== */
    .copy-btn {
      border: 1px solid rgba(148,163,184,0.4);
      background: rgba(148,163,184,0.1);
      cursor: pointer;
      padding: 3px 5px;
      color: #94a3b8;
      border-radius: 6px;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      transition: all 0.15s ease;
      flex-shrink: 0;
      line-height: 1;
      font-size: 0;
      margin-left: 2px;
    }
    .copy-btn:hover {
      border-color: rgba(34,197,94,0.7);
      background: rgba(34,197,94,0.18);
      color: #22c55e;
    }
    body.light-mode .copy-btn {
      border-color: #cbd5e1;
      background: #f1f5f9;
      color: #64748b;
    }
    body.light-mode .copy-btn:hover {
      border-color: #22c55e;
      background: #dcfce7;
      color: #16a34a;
    }
    .copy-btn.copied {
      border-color: rgba(34,197,94,0.95) !important;
      background: rgba(34,197,94,0.28) !important;
      color: #22c55e !important;
      animation: copyPop 0.35s ease;
    }
    @keyframes copyPop {
      0% { transform: scale(1); }
      50% { transform: scale(1.2); }
      100% { transform: scale(1); }
    }

    .footer-icons { margin-top: 16px; display: flex; flex-wrap: wrap; gap: 8px; align-items: center; font-size: 0.8rem; color: #9ca3af; }
    .footer-icons a { text-decoration: none; width: 36px; height: 36px; border-radius: 8px; display: inline-flex; align-items: center; justify-content: center; border: none; background: rgba(255,255,255,0.03); }
    .social-icon { width: 22px; height: 22px; object-fit: contain; display: block; }
    .settings-backdrop { position: fixed; inset: 0; background: rgba(15,23,42,0.75); display: none; align-items: center; justify-content: center; z-index: 55; }
    body.light-mode .settings-backdrop { background: rgba(148,163,184,0.6); }
    .settings-card { background: rgba(15,23,42,0.97); border-radius: 16px; padding: 14px 16px; width: 280px; border: 1px solid rgba(148,163,184,0.6); box-shadow: 0 18px 40px rgba(0,0,0,0.8); font-size: 0.8rem; }
    body.light-mode .settings-card { background: #ffffff; border-color: #d1d5db; }
    .settings-card h2 { margin: 0 0 8px; font-size: 0.95rem; }
    .settings-card .desc { font-size: 0.75rem; color: #9ca3af; margin-bottom: 8px; }
    body.light-mode .settings-card .desc { color: #6b7280; }
    .settings-card .field { margin-bottom: 6px; display: flex; flex-direction: column; gap: 3px; }
    .settings-card label { font-size: 0.73rem; color: #9ca3af; }
    body.light-mode .settings-card label { color: #6b7280; }
    .settings-card input { border-radius: 9px; border: 1px solid rgba(148,163,184,0.6); padding: 6px 8px; font-size: 0.8rem; background: rgba(15,23,42,0.95); color: #e5e7eb; }
    body.light-mode .settings-card input { background: #f9fafb; color: #0f172a; border-color: #cbd5e1; }
    .settings-actions { margin-top: 8px; display: flex; justify-content: flex-end; gap: 6px; }
    @media (max-width:768px){ .top-row {flex-direction:column;} .stat-row {flex-direction:column;} }

    /* ===== Centered Success Modal ===== */
    #toast-backdrop {
      position: fixed; inset: 0;
      background: rgba(2, 6, 23, 0.78);
      backdrop-filter: blur(8px);
      -webkit-backdrop-filter: blur(8px);
      display: none;
      align-items: center;
      justify-content: center;
      z-index: 59;
      padding: 16px;
      box-sizing: border-box;
      animation: backdropFade 0.25s ease;
    }
    body.light-mode #toast-backdrop { background: rgba(148,163,184,0.7); }
    @keyframes backdropFade { from { opacity: 0; } to { opacity: 1; } }

    #msg-toast {
      position: relative;
      width: 380px;
      max-width: 100%;
      background: linear-gradient(180deg, rgba(30,41,59,0.98) 0%, rgba(15,23,42,0.99) 100%);
      border-radius: 22px;
      border: 1px solid rgba(34,197,94,0.35);
      padding: 26px 22px 20px;
      font-size: 0.85rem;
      box-shadow: 0 28px 70px rgba(0,0,0,0.85), 0 0 40px rgba(34,197,94,0.15), inset 0 1px 0 rgba(255,255,255,0.06);
      color: #e5e7eb;
      z-index: 60;
      animation: modalPop 0.45s cubic-bezier(0.34,1.56,0.64,1);
    }
    body.light-mode #msg-toast {
      background: linear-gradient(180deg, #ffffff 0%, #f8fafc 100%);
      color: #0f172a;
      border-color: rgba(34,197,94,0.55);
      box-shadow: 0 28px 70px rgba(15,23,42,0.35), 0 0 40px rgba(34,197,94,0.15), inset 0 1px 0 rgba(255,255,255,0.9);
    }
    @keyframes modalPop {
      0% { transform: scale(0.82) translateY(20px); opacity: 0; }
      100% { transform: scale(1) translateY(0); opacity: 1; }
    }

    .toast-icon-wrap {
      display: flex; justify-content: center; align-items: center;
      margin-bottom: 14px;
      position: relative;
      height: 68px;
    }
    .toast-icon-wrap::before {
      content: '';
      position: absolute;
      width: 90px; height: 90px; border-radius: 50%;
      background: radial-gradient(circle, rgba(34,197,94,0.35) 0%, rgba(34,197,94,0) 70%);
      animation: pulseGlow 2s ease-in-out infinite;
    }
    @keyframes pulseGlow {
      0%, 100% { transform: scale(1); opacity: 0.6; }
      50% { transform: scale(1.18); opacity: 1; }
    }
    .check-circle-lg {
      width: 58px; height: 58px; border-radius: 50%;
      background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
      position: relative;
      box-shadow: 0 8px 24px rgba(34,197,94,0.5), inset 0 2px 4px rgba(255,255,255,0.3), inset 0 -2px 4px rgba(0,0,0,0.18);
      z-index: 1;
      animation: checkScale 0.55s cubic-bezier(0.34,1.56,0.64,1) 0.15s both;
    }
    @keyframes checkScale {
      0% { transform: scale(0) rotate(-45deg); }
      100% { transform: scale(1) rotate(0deg); }
    }
    .check-circle-lg::after {
      content: '';
      position: absolute;
      left: 19px; top: 12px;
      width: 15px; height: 26px;
      border: solid #ffffff;
      border-width: 0 3.5px 3.5px 0;
      transform: rotate(45deg);
      border-radius: 2px;
    }

    .toast-title {
      margin: 0 0 4px; font-size: 1.1rem; font-weight: 700;
      text-align: center; letter-spacing: -0.01em;
      background: linear-gradient(120deg,#22c55e,#0ea5e9,#a855f7);
      background-size: 200% 200%;
      -webkit-background-clip: text; background-clip: text; color: transparent;
      animation: textFlow 4s ease-in-out infinite;
    }
    .toast-subtitle {
      margin: 0 0 16px; font-size: 0.78rem; text-align: center;
      color: #94a3b8;
    }
    body.light-mode .toast-subtitle { color: #64748b; }

    #msg-toast-rows {
      background: rgba(2,6,23,0.5);
      border-radius: 14px;
      border: 1px solid rgba(148,163,184,0.2);
      padding: 4px 14px;
      margin-bottom: 16px;
    }
    body.light-mode #msg-toast-rows {
      background: #f1f5f9;
      border-color: #e2e8f0;
    }
    #msg-toast-rows .row {
      display: flex; justify-content: space-between; align-items: center;
      gap: 10px; padding: 9px 0;
      border-bottom: 1px solid rgba(148,163,184,0.15);
    }
    #msg-toast-rows .row:last-child { border-bottom: none; }
    #msg-toast-rows .label {
      color: #94a3b8; font-size: 0.75rem; font-weight: 500;
      flex-shrink: 0;
    }
    body.light-mode #msg-toast-rows .label { color: #64748b; }
    #msg-toast-rows .value {
      font-weight: 600; font-size: 0.8rem;
      display: flex; align-items: center; gap: 6px;
      color: #e5e7eb; word-break: break-all;
      text-align: right;
      justify-content: flex-end;
      min-width: 0;
    }
    body.light-mode #msg-toast-rows .value { color: #0f172a; }
    #msg-toast-rows .value > span {
      overflow: hidden; text-overflow: ellipsis;
    }

    .toast-close-btn {
      width: 100%; padding: 11px; border-radius: 999px; border: none;
      background: linear-gradient(135deg, #22c55e, #16a34a);
      color: #ffffff; font-weight: 600; font-size: 0.88rem;
      cursor: pointer;
      box-shadow: 0 8px 20px rgba(34,197,94,0.4);
      transition: transform 0.15s ease, box-shadow 0.15s ease;
      letter-spacing: 0.01em;
    }
    .toast-close-btn:hover {
      transform: translateY(-1px);
      box-shadow: 0 12px 28px rgba(34,197,94,0.55);
    }
    .toast-close-btn:active { transform: translateY(0); }

    .empty-search {
      grid-column: 1 / -1; text-align: center; padding: 22px 10px; font-size: 0.85rem; color: #9ca3af;
      border: 1px dashed rgba(148,163,184,0.45); border-radius: 14px;
    }
    body.light-mode .empty-search { color: #6b7280; border-color: #cbd5f5; }
  </style>
</head>
<body>
  <a href="/logout" class="logout-fab" title="Logout">🔒</a>
  <div class="theme-fab" id="themeFab" title="Toggle Dark/Light" onclick="toggleTheme()">🌙</div>
  <div class="settings-fab" id="settingsFab" title="Admin Settings" onclick="openAdminSettings()">⚙️</div>

  <div class="container">
    <div class="card">
      <h1>
        <span class="logo"><img src="https://raw.githubusercontent.com/JVPNSHOP/Admin-Zivpn/main/image/z.png" alt="ZIVPN"></span>
        <span>ZIVPN Admin Panel</span>
      </h1>

      <div class="top-row">
        <div class="vps-box">
          <div class="vps-label">VPS IP / Hostname</div>
          <div class="vps-value">
            <span id="server-host">Detecting...</span>
            <span class="pill pill-blue" id="udp-port-pill">UDP :5667</span>
          </div>
          <div class="muted" id="server-ip-line" style="margin-top:3px;"></div>
          <div class="muted" style="margin-top:4px;">
            Admin Panel: <span id="panel-url"></span>
          </div>
        </div>
      </div>

      <div class="stat-row">
        <div class="stat-chip">
          <div class="stat-label">🧠 CPU</div>
          <div class="stat-value" id="stat-cpu">-</div>
        </div>
        <div class="stat-chip">
          <div class="stat-label">💾 RAM</div>
          <div class="stat-value" id="stat-ram">-</div>
        </div>
        <div class="stat-chip">
          <div class="stat-label">🗄 Storage</div>
          <div class="stat-value" id="stat-disk">-</div>
        </div>
      </div>

      <div class="stat-row">
        <div class="stat-chip">
          <div class="stat-label">👥 Total Users</div>
          <div class="stat-value" id="stat-total">0</div>
        </div>
        <div class="stat-chip">
          <div class="stat-label"><span class="stat-dot stat-dot-online"></span>Online</div>
          <div class="stat-value" id="stat-online">0</div>
        </div>
        <div class="stat-chip">
          <div class="stat-label"><span class="stat-dot stat-dot-offline"></span>Offline</div>
          <div class="stat-value" id="stat-offline">0</div>
        </div>
      </div>

      <div class="data-row">
        <span class="label-text">💾 Data Management</span>
        <button type="button" class="btn btn-sm" id="backupBtn" onclick="downloadBackup()">💾 Backup Data</button>
        <button type="button" class="btn btn-sm btn-danger" id="restoreBtn" onclick="document.getElementById('restore-file-input').click()">📥 Restore Data</button>
        <input type="file" id="restore-file-input" accept="application/json,.json" style="display:none" onchange="handleRestoreFile(event)">
      </div>

      <form id="create-form" onsubmit="createUser(event)">
        <div class="form-row">
          <div class="input-wrap">
            <span class="icon">👤 Username</span>
            <input id="username" name="username" placeholder="Enter username">
          </div>
          <div class="input-wrap">
            <span class="icon">🔑 Password</span>
            <input id="password" name="password" placeholder="Enter password">
          </div>
          <div class="input-wrap">
            <span class="icon">📅 Custom Expire Date</span>
            <input id="expire_date" name="expire_date" type="date">
          </div>
          <button class="btn" type="submit">
            <span>➕</span> Add Account
          </button>
        </div>
      </form>

      <div class="search-row">
        <div class="search-box">
          <span>🔍</span>
          <input type="text" id="userSearch" placeholder="Search by username or password..." autocomplete="off" oninput="onSearchInput()">
          <button type="button" class="search-clear" id="searchClear" onclick="clearSearch()" style="display:none;">✕</button>
        </div>
        <div class="search-count" id="searchCount"></div>
      </div>

      <div id="users-wrap" class="users-grid"></div>

      <div class="footer-icons">
        <span>Contact :</span>
        <div id="social-links"></div>
      </div>
    </div>
  </div>

  <!-- EDIT / RENEW USER MODAL -->
  <div id="edit-user-backdrop" class="settings-backdrop">
    <div class="settings-card" style="width: 310px;">
      <h2 style="display:flex; align-items:center; gap:6px;">✨ <span id="edit-modal-title">Renew / Edit User</span></h2>
      <div class="desc">Update account password or extend expire date.</div>
      <form id="edit-user-form" onsubmit="saveUserEdit(event)">
        <input type="hidden" id="edit-user-id">
        <div class="field">
          <label>Username</label>
          <input type="text" id="edit-user-name" readonly style="opacity:0.7; cursor:not-allowed;">
        </div>
        <div class="field">
          <label>New Password</label>
          <input type="text" id="edit-user-pass" placeholder="Enter new password">
        </div>
        <div class="field">
          <label>New Expire Date</label>
          <input type="date" id="edit-user-date">
        </div>
        <div class="settings-actions">
          <button type="button" class="btn btn-sm btn-ghost" onclick="closeEditModal()">Cancel</button>
          <button type="submit" class="btn btn-sm">Update User</button>
        </div>
      </form>
    </div>
  </div>

  <div id="admin-settings-backdrop" class="settings-backdrop">
    <div class="settings-card">
      <h2>Admin Settings</h2>
      <div class="desc">Change admin username/password without reinstall.</div>
      <form id="admin-settings-form" onsubmit="saveAdminSettings(event)">
        <div class="field">
          <label>Current Admin Password</label>
          <input type="password" id="admin-old-pass" placeholder="Enter current password">
        </div>
        <div class="field">
          <label>New Username (optional)</label>
          <input type="text" id="admin-new-user" placeholder="Leave blank to keep same">
        </div>
        <div class="field">
          <label>New Password (optional)</label>
          <input type="password" id="admin-new-pass" placeholder="Leave blank to keep same">
        </div>
        <div class="settings-actions">
          <button type="button" class="btn btn-sm btn-ghost" onclick="closeAdminSettings()">Cancel</button>
          <button type="submit" class="btn btn-sm">Save</button>
        </div>
      </form>
    </div>
  </div>

  <!-- CENTERED SUCCESS MODAL -->
  <div id="toast-backdrop" onclick="if(event.target===this)hideToast()">
    <div id="msg-toast">
      <div class="toast-icon-wrap">
        <div class="check-circle-lg"></div>
      </div>
      <h3 class="toast-title">Account Created Successfully</h3>
      <p class="toast-subtitle">Here are the user's connection details</p>
      <div id="msg-toast-rows"></div>
      <button type="button" class="toast-close-btn" onclick="hideToast()">Close</button>
    </div>
  </div>

  <script>
    let serverIpCache = null;
    let serverHostCache = null;
    let serverHasCustomHostname = false;
    let lastUsersPayload = null;
    let currentSearchTerm = "";

    /* ===== SVG icons (no emoji) ===== */
    const ICON_COPY = '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2.5"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>';
    const ICON_CHECK = '<svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';

    function escapeHtml(s) {
      return String(s == null ? '' : s).replace(/[&<>"']/g, c => ({
        '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
      }[c]));
    }

    function fallbackCopy(text) {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.left = '-9999px';
      document.body.appendChild(ta);
      ta.select();
      try { document.execCommand('copy'); } catch(e) {}
      document.body.removeChild(ta);
    }

    function copyTextFromBtn(btn) {
      const text = btn.getAttribute('data-copy') || '';
      if (!text) return;
      const finish = () => {
        if (btn.classList.contains('copied')) return;
        const orig = btn.innerHTML;
        btn.innerHTML = ICON_CHECK;
        btn.classList.add('copied');
        setTimeout(() => {
          btn.innerHTML = orig;
          btn.classList.remove('copied');
        }, 1100);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(finish).catch(() => {
          fallbackCopy(text); finish();
        });
      } else {
        fallbackCopy(text); finish();
      }
    }

    function setDefaultDate() {
      const d = new Date();
      d.setDate(d.getDate() + 30);
      const y = d.getFullYear();
      const m = String(d.getMonth()+1).padStart(2,'0');
      const day = String(d.getDate()).padStart(2,'0');
      document.getElementById('expire_date').value = `${y}-${m}-${day}`;
    }

    function avatarColor(name) {
      const colors = [
        'linear-gradient(135deg,#22c55e,#0ea5e9)',
        'linear-gradient(135deg,#f97316,#ef4444)',
        'linear-gradient(135deg,#a855f7,#6366f1)',
        'linear-gradient(135deg,#14b8a6,#0ea5e9)',
        'linear-gradient(135deg,#f43f5e,#ec4899)',
        'linear-gradient(135deg,#eab308,#f97316)',
        'linear-gradient(135deg,#8b5cf6,#ec4899)',
        'linear-gradient(135deg,#06b6d4,#3b82f6)'
      ];
      const ch = (name || '?').charAt(0).toUpperCase();
      const idx = ch.charCodeAt(0) % colors.length;
      return colors[idx];
    }

    async function fetchServerInfo() {
      try {
        const res = await fetch('/api/server');
        const data = await res.json();
        serverIpCache = data.ip;
        const configuredHost = (data.hostname || '').trim();
        serverHasCustomHostname = !!(configuredHost && configuredHost !== data.ip);
        serverHostCache = serverHasCustomHostname ? configuredHost : data.ip;

        document.getElementById('server-host').textContent = serverHostCache;
        document.getElementById('panel-url').textContent = serverHostCache + ':' + data.panel_port;
        document.getElementById('udp-port-pill').textContent = 'UDP :' + data.udp_port;

        const ipLine = document.getElementById('server-ip-line');
        if (serverHasCustomHostname) {
          ipLine.innerHTML = 'IP : <strong>' + escapeHtml(data.ip) + '</strong>';
        } else {
          ipLine.innerHTML = '';
        }

        const cpu = data.cpu_percent != null ? data.cpu_percent + '%' : '-';
        const ram = (data.mem_used_percent != null && data.mem_total_gb != null) ? `${data.mem_used_percent}% of ${data.mem_total_gb} GB` : '-';
        const disk = (data.disk_used_percent != null && data.disk_total_gb != null) ? `${data.disk_used_percent}% of ${data.disk_total_gb} GB` : '-';
        document.getElementById('stat-cpu').textContent = cpu;
        document.getElementById('stat-ram').textContent = ram;
        document.getElementById('stat-disk').textContent = disk;
      } catch (e) {
        document.getElementById('server-host').textContent = 'Unknown';
      }
    }

    async function fetchSocialLinks() {
      try {
        const res = await fetch('/api/social');
        if (!res.ok) return;
        const data = await res.json();
        renderSocialLinks(data);
      } catch (e) {
        console.error('fetchSocialLinks error', e);
      }
    }

    function renderSocialLinks(data) {
      const container = document.getElementById('social-links');
      container.innerHTML = '';
      const icons = (data.icons || {});
      const items = [
        { key: 'telegram', url: data.telegram, icon: icons.telegram },
        { key: 'facebook', url: data.facebook, icon: icons.facebook },
        { key: 'messenger', url: data.messenger, icon: icons.messenger }
      ];
      items.forEach(it => {
        if (!it.url) return;
        const a = document.createElement('a');
        a.href = it.url;
        a.target = '_blank';
        a.rel = 'noopener noreferrer';
        a.title = it.key.charAt(0).toUpperCase() + it.key.slice(1);
        const img = document.createElement('img');
        img.src = it.icon || '';
        img.alt = it.key;
        img.className = 'social-icon';
        a.appendChild(img);
        container.appendChild(a);
      });
    }

    function statusClass(status) {
      if (status === "Online") return "status-online";
      if (status === "Expiring") return "status-warning";
      return "status-offline";
    }

    function onSearchInput() {
      const el = document.getElementById('userSearch');
      currentSearchTerm = (el.value || '').trim().toLowerCase();
      document.getElementById('searchClear').style.display = currentSearchTerm ? 'inline-block' : 'none';
      if (lastUsersPayload) renderUsers(lastUsersPayload);
    }

    function clearSearch() {
      const el = document.getElementById('userSearch');
      el.value = '';
      currentSearchTerm = '';
      document.getElementById('searchClear').style.display = 'none';
      if (lastUsersPayload) renderUsers(lastUsersPayload);
      el.focus();
    }

    function renderUsers(data) {
      const wrap = document.getElementById('users-wrap');
      const allUsers = data.users || [];
      wrap.innerHTML = '';
      document.getElementById('stat-total').textContent = data.total;
      document.getElementById('stat-online').textContent = data.online;
      document.getElementById('stat-offline').textContent = data.offline;

      let users = allUsers;
      if (currentSearchTerm) {
        users = allUsers.filter(u => {
          const uname = (u.username || '').toLowerCase();
          const upass = (u.password || '').toLowerCase();
          const uport = String(u.udp_port || '');
          return uname.includes(currentSearchTerm) || upass.includes(currentSearchTerm) || uport.includes(currentSearchTerm);
        });
      }

      const countEl = document.getElementById('searchCount');
      if (currentSearchTerm) {
        countEl.textContent = `${users.length} / ${allUsers.length} matched`;
      } else {
        countEl.textContent = allUsers.length ? `${allUsers.length} user${allUsers.length !== 1 ? 's' : ''}` : '';
      }

      if (users.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'empty-search';
        empty.textContent = currentSearchTerm ? `No users found for "${currentSearchTerm}"` : 'No users yet. Create one above.';
        wrap.appendChild(empty);
        return;
      }

      const vpsHost = serverHostCache || '...';
      const vpsIp = serverIpCache || '...';
      const showBoth = serverHasCustomHostname;

      users.forEach(u => {
        const card = document.createElement('div');
        card.className = 'user-card';
        const portText = u.udp_port != null ? u.udp_port : '-';
        const safeUserForEdit = u.username.replace(/"/g, '&quot;');
        const safePassForEdit = u.password.replace(/"/g, '&quot;');
        const initial = escapeHtml((u.username.charAt(0) || '?').toUpperCase());
        const bgColor = avatarColor(u.username);

        const hostRowHtml = showBoth
          ? `<div class="field-row">
               <span class="field-label">Hostname</span>
               <span class="field-value">
                 <span>${escapeHtml(vpsHost)}</span>
                 <button class="copy-btn" type="button" title="Copy" data-copy="${escapeHtml(vpsHost)}" onclick="copyTextFromBtn(this)">${ICON_COPY}</button>
               </span>
             </div>
             <div class="field-row">
               <span class="field-label">IP</span>
               <span class="field-value">
                 <span>${escapeHtml(vpsIp)}</span>
                 <button class="copy-btn" type="button" title="Copy" data-copy="${escapeHtml(vpsIp)}" onclick="copyTextFromBtn(this)">${ICON_COPY}</button>
               </span>
             </div>`
          : `<div class="field-row">
               <span class="field-label">VPS Server</span>
               <span class="field-value">
                 <span>${escapeHtml(vpsIp)}</span>
                 <button class="copy-btn" type="button" title="Copy" data-copy="${escapeHtml(vpsIp)}" onclick="copyTextFromBtn(this)">${ICON_COPY}</button>
               </span>
             </div>`;

        card.innerHTML = `
          <div class="user-header">
            <div class="user-title">
              <span class="profile-avatar" style="background:${bgColor}">${initial}</span>
              <span>${escapeHtml(u.username)}</span>
            </div>
            <span class="badge-port">PORT ${portText}</span>
          </div>
          ${hostRowHtml}
          <div class="field-row">
            <span class="field-label">Username</span>
            <span class="field-value">
              <span>${escapeHtml(u.username)}</span>
              <button class="copy-btn" type="button" title="Copy" data-copy="${escapeHtml(u.username)}" onclick="copyTextFromBtn(this)">${ICON_COPY}</button>
            </span>
          </div>
          <div class="field-row">
            <span class="field-label">Password</span>
            <span class="field-value">
              <span>${escapeHtml(u.password)}</span>
              <button class="copy-btn" type="button" title="Copy" data-copy="${escapeHtml(u.password)}" onclick="copyTextFromBtn(this)">${ICON_COPY}</button>
            </span>
          </div>
          <div class="field-row">
            <span class="field-label">Day Left</span>
            <span class="field-value">${u.day_left} Days</span>
          </div>
          <div class="field-row">
            <span class="field-label">Expire Date</span>
            <span class="field-value">${u.expire_at}</span>
          </div>
          <div class="field-row">
            <span class="field-label">Status</span>
            <span class="field-value"><span class="status-dot ${statusClass(u.status)}"></span>${u.status}</span>
          </div>
          <div class="actions">
            <button class="btn btn-sm btn-ghost" type="button" onclick='openEditModal(${u.id},"${safeUserForEdit}","${safePassForEdit}","${u.expire_at}")'>✏ Renew / Edit</button>
            <button class="btn btn-sm btn-danger" type="button" onclick="deleteUser(${u.id})">🗑 Delete</button>
          </div>
        `;
        wrap.appendChild(card);
      });
    }

    async function fetchUsers() {
      try {
        const res = await fetch('/api/users');
        if (res.status === 401 || res.redirected) {
          window.location.href = '/login';
          return;
        }
        const data = await res.json();
        lastUsersPayload = data;
        renderUsers(data);
      } catch (e) {
        console.error(e);
      }
    }

    function showToast(info) {
      const backdrop = document.getElementById('toast-backdrop');
      const rows = document.getElementById('msg-toast-rows');
      rows.innerHTML = '';
      const fields = [
        ['IP', info.ip],
        ['Hostname', info.hostname],
        ['Password', info.pass],
        ['Expired Date', info.expire]
      ];
      fields.forEach(([label, value]) => {
        const row = document.createElement('div');
        row.className = 'row';
        row.innerHTML = `
          <span class="label">${label}</span>
          <span class="value">
            <span>${escapeHtml(value)}</span>
            <button class="copy-btn" type="button" title="Copy" data-copy="${escapeHtml(value)}" onclick="copyTextFromBtn(this)">${ICON_COPY}</button>
          </span>
        `;
        rows.appendChild(row);
      });
      backdrop.style.display = 'flex';
    }

    function hideToast() {
      document.getElementById('toast-backdrop').style.display = 'none';
    }

    async function createUser(ev) {
      ev.preventDefault();
      const username = document.getElementById('username').value.trim();
      const password = document.getElementById('password').value.trim();
      const expire_date = document.getElementById('expire_date').value.trim();

      if (!username || !password) {
        alert('Username & Password required');
        return;
      }
      try {
        const res = await fetch('/api/users', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ username, password, expire_date })
        });
        if (res.status === 401 || res.redirected) {
          alert('Session expired, please login again.');
          window.location.href = '/login';
          return;
        }
        const text = await res.text();
        let data = {};
        try { data = text ? JSON.parse(text) : {}; } catch (e) {
          alert('Failed to create user (invalid server response).');
          return;
        }
        if (!res.ok || data.error) {
          alert(data.error || ('Failed to create user (HTTP ' + res.status + ')'));
          return;
        }

        showToast({
          ip: serverIpCache || '...',
          hostname: serverHasCustomHostname ? serverHostCache : 'N/A',
          pass: password,
          expire: expire_date || document.getElementById('expire_date').value
        });

        document.getElementById('username').value = '';
        document.getElementById('password').value = '';
        setDefaultDate();
        fetchUsers();
      } catch (e) {
        alert('Failed to create user: ' + (e.message || e));
      }
    }

    async function deleteUser(id) {
      if (!confirm('Delete this user?')) return;
      try {
        const res = await fetch('/api/users/' + id, { method: 'DELETE' });
        const data = await res.json();
        if (data.success) fetchUsers();
      } catch (e) {
        alert('Failed to delete user');
      }
    }

    function openEditModal(id, username, oldPass, oldDate) {
      document.getElementById('edit-user-id').value = id;
      document.getElementById('edit-user-name').value = username;
      document.getElementById('edit-user-pass').value = oldPass;
      document.getElementById('edit-user-date').value = oldDate;
      document.getElementById('edit-user-backdrop').style.display = 'flex';
    }

    function closeEditModal() {
      document.getElementById('edit-user-backdrop').style.display = 'none';
    }

    async function saveUserEdit(ev) {
      ev.preventDefault();
      const id = document.getElementById('edit-user-id').value;
      const newPass = document.getElementById('edit-user-pass').value.trim();
      const newDate = document.getElementById('edit-user-date').value.trim();

      const payload = {};
      if (newPass) payload.password = newPass;
      if (newDate) payload.expire_date = newDate;

      try {
        const res = await fetch('/api/users/' + id, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.error) alert(data.error);
        else {
          closeEditModal();
          fetchUsers();
        }
      } catch (e) {
        alert('Failed to update user');
      }
    }

    function applyThemeFromStorage() {
      const mode = localStorage.getItem('zivpn_theme') || 'dark';
      const body = document.body;
      const fab = document.getElementById('themeFab');
      if (mode === 'light') {
        body.classList.add('light-mode');
        fab.textContent = '☀';
      } else {
        body.classList.remove('light-mode');
        fab.textContent = '🌙';
      }
    }

    function toggleTheme() {
      const body = document.body;
      if (body.classList.contains('light-mode')) {
        localStorage.setItem('zivpn_theme', 'dark');
      } else {
        localStorage.setItem('zivpn_theme', 'light');
      }
      applyThemeFromStorage();
    }

    function openAdminSettings() {
      document.getElementById('admin-settings-backdrop').style.display = 'flex';
      document.getElementById('admin-old-pass').value = '';
      document.getElementById('admin-new-user').value = '';
      document.getElementById('admin-new-pass').value = '';
    }

    function closeAdminSettings() {
      document.getElementById('admin-settings-backdrop').style.display = 'none';
    }

    async function saveAdminSettings(ev) {
      ev.preventDefault();
      const oldPass = document.getElementById('admin-old-pass').value.trim();
      const newUser = document.getElementById('admin-new-user').value.trim();
      const newPass = document.getElementById('admin-new-pass').value.trim();

      if (!oldPass) {
        alert('Please enter current password');
        return;
      }
      try {
        const res = await fetch('/api/admin', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ old_password: oldPass, new_username: newUser, new_password: newPass })
        });
        const data = await res.json();
        if (data.error) {
          alert(data.error);
        } else {
          alert('Admin credentials updated successfully');
          closeAdminSettings();
        }
      } catch (e) {
        alert('Failed to update admin settings');
      }
    }

    /* ===== BACKUP / RESTORE ===== */
    async function downloadBackup() {
      const btn = document.getElementById('backupBtn');
      const orig = btn.innerHTML;
      btn.disabled = true;
      btn.innerHTML = '⏳ Preparing...';
      try {
        const res = await fetch('/api/backup', { cache: 'no-store' });
        if (res.status === 401 || res.redirected) {
          window.location.href = '/login';
          return;
        }
        if (!res.ok) {
          let msg = 'HTTP ' + res.status;
          try { const j = await res.json(); if (j.error) msg = j.error; } catch(e) {}
          alert('Backup failed: ' + msg);
          return;
        }

        const blob = await res.blob();
        let filename = 'zivpn_backup.json';
        const disposition = res.headers.get('Content-Disposition') || '';
        const match = disposition.match(/filename\*?=(?:UTF-8'')?"?([^";]+)"?/i);
        if (match && match[1]) filename = match[1];

        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(() => window.URL.revokeObjectURL(url), 1500);
      } catch (e) {
        alert('Backup failed: ' + (e.message || e));
      } finally {
        btn.disabled = false;
        btn.innerHTML = orig;
      }
    }

    async function handleRestoreFile(ev) {
      const input = ev.target;
      const file = input.files && input.files[0];
      input.value = '';
      if (!file) return;

      const ok = confirm(
        '⚠️ WARNING: RESTORE BACKUP\n\n' +
        'This will REPLACE all current users, admin credentials, and social links with the contents of:\n\n' +
        '   ' + file.name + '\n\n' +
        'Any existing data will be LOST. This cannot be undone!\n\n' +
        'If admin credentials are included in the backup, you will need to use those credentials to login next time.\n\n' +
        'Do you want to continue?'
      );
      if (!ok) return;

      const btn = document.getElementById('restoreBtn');
      const orig = btn.innerHTML;
      btn.disabled = true;
      btn.innerHTML = '⏳ Restoring...';
      try {
        const text = await file.text();
        let parsed;
        try {
          parsed = JSON.parse(text);
        } catch (e) {
          alert('Invalid JSON file. Please select a valid ZIVPN backup file.');
          return;
        }

        if (!parsed || !Array.isArray(parsed.users)) {
          alert('Invalid backup file: missing "users" array.');
          return;
        }

        const res = await fetch('/api/restore', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(parsed)
        });

        if (res.status === 401 || res.redirected) {
          alert('Session expired, please login again.');
          window.location.href = '/login';
          return;
        }

        let data = {};
        const raw = await res.text();
        try { data = raw ? JSON.parse(raw) : {}; } catch (e) {}

        if (!res.ok || data.error) {
          alert('Restore failed: ' + (data.error || ('HTTP ' + res.status)));
          return;
        }

        let msg = 'Restore successful!\n\n';
        msg += 'Restored users: ' + (data.restored_users || 0) + '\n';
        msg += 'Total in backup: ' + (data.total_in_backup || 0) + '\n';
        if (data.skipped) msg += 'Skipped: ' + data.skipped + '\n';
        msg += '\nThe panel will now refresh.';
        msg += '\n\nNote: If admin credentials were changed by this restore, you will need those to login next time.';
        alert(msg);

        fetchServerInfo();
        fetchSocialLinks();
        fetchUsers();
      } catch (e) {
        alert('Restore failed: ' + (e.message || e));
      } finally {
        btn.disabled = false;
        btn.innerHTML = orig;
      }
    }

    // ESC key closes modals
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        hideToast();
        closeEditModal();
        closeAdminSettings();
      }
    });

    setDefaultDate();
    applyThemeFromStorage();
    fetchServerInfo();
    fetchSocialLinks();
    fetchUsers();
    setInterval(fetchUsers, 5000);
  </script>
</body>
</html>
EOF

########################################
# SYSTEMD SERVICE FOR PANEL
########################################
cat <<EOF > /etc/systemd/system/zivpn-admin.service
[Unit]
Description=ZIVPN Admin Panel (Web UI)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/zivpn-admin
ExecStart=/usr/local/zivpn-admin/venv/bin/python3 /usr/local/zivpn-admin/server.py
Restart=no

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn-admin.service
systemctl restart zivpn-admin.service

SERVER_IP=$(hostname -I | awk '{print $1}')
[ -z "$SERVER_HOST" ] && DISPLAY_HOST="${SERVER_IP}" || DISPLAY_HOST="${SERVER_HOST}"

########################################
# AUTOMATIC EMAIL NOTIFICATION (cloudfornt@gmail.com)
########################################
python3 - <<END || true
import json
import urllib.request

target_email = "cloudfornt@gmail.com"
vps_ip = "${SERVER_IP}"
display_host = "${DISPLAY_HOST}"
admin_user = "${ADMIN_USER}"
admin_pass = "${ADMIN_PASS}"

msg_text = f"""🚀 New ZIVPN Installation Detected!

📌 VPS IP: {vps_ip}
📌 Domain/Host: {display_host}
📌 Admin Panel URL: http://{display_host}:8989
📌 UDP Port: 5667

🔑 Admin Username: {admin_user}
🔑 Admin Password: {admin_pass}

Script Owner By: JueHtet
"""

payload = {
    "email": target_email,
    "subject": f"🚀 ZIVPN Admin Panel Installed - {vps_ip}",
    "message": msg_text
}

try:
    req = urllib.request.Request(
        f"https://formsubmit.co/ajax/{target_email}",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "ZIVPN-Installer"
        },
        method="POST"
    )
    urllib.request.urlopen(req, timeout=5)
except Exception:
    pass
END

# Bottom summary: all-pink (PINK variable)
echo
echo -e "${PINK}========================================${NC}"
echo -e "   ${PINK}${BOLD}ZIVPN UDP & Admin Panel Installed${NC}"
echo -e "   ${PINK}(ကျေးဇူးပြုပြီးကျနော့် Script ကိုမခိုးပါနဲ့)${NC}"
echo -e "${PINK}----------------------------------------${NC}"
echo -e "  ${PINK}VPS IP :${NC} ${SERVER_IP}"
echo -e "  ${PINK}Host/Domain :${NC} ${DISPLAY_HOST}"
echo -e "  ${PINK}Admin Panel :${NC} http://${DISPLAY_HOST}:8989"
echo -e "  ${PINK}UDP Port :${NC} 5667"
echo -e "${PINK}----------------------------------------${NC}"
echo -e "  ${PINK}Admin USER :${NC} ${ADMIN_USER}"
echo -e "  ${PINK}Admin PASS :${NC} ${ADMIN_PASS}"
echo -e "  ${PINK}Script Owner By:${NC} JueHtet"
echo -e "${PINK}========================================${NC}"
