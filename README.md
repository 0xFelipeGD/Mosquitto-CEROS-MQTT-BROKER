# Mosquitto-CEROS-MQTT-BROKER

MQTT broker (Eclipse Mosquitto 2.0) para o twin ROS 2 do **CEROS** rover.

**Estado**: F2 data pipeline — broker simples username/password sem TLS. coturn (WebRTC TURN) volta em F4, TLS/cert hardening volta em F10.

Submódulo do parent [ROS2-RCS](https://github.com/0xFelipeGD/ROS2-RCS).

[![Mosquitto](https://img.shields.io/badge/Mosquitto-2.0-660066)]() [![Phase](https://img.shields.io/badge/phase-2-yellow)]()

---

## 📐 O que faz (F2)

- **Mosquitto MQTT broker** em duas portas:
  - **1883** plaintext — Jetson `ceros_mqtt_bridge` (cliente `mqtt_client`)
  - **9001** WebSocket — Electron frontend (`mqtt.js`)
- **Single user `ceros`** com acesso total a `ceros/#`
- **User `health`** read-only em `$SYS/#` (usado pelo healthcheck)

Contrato canónico de tópicos: [`INTERFACE_CONTRACT.md`](https://github.com/0xFelipeGD/ROS2-RCS/blob/main/INTERFACE_CONTRACT.md) no parent.

```
        ┌────────────────────────────────┐
        │  VPS (Mosquitto-CEROS-MQTT)    │
        │                                │
        │  ┌──────────────────────────┐  │
        │  │ Mosquitto 2.0            │  │
        │  │ :1883 MQTT plaintext     │  │
        │  │ :9001 MQTT WebSocket     │  │
        │  └──────────────────────────┘  │
        └────────────────────────────────┘
                  ↑                ↑
                  │ MQTT           │ WebSocket
                  │                │
   ┌──────────────┐    ┌──────────────────┐
   │  CEROS       │    │  OPERADOR         │
   │  Jetson      │←──→│  Electron app     │
   │  (1883)      │    │  (9001 WS)        │
   └──────────────┘    └──────────────────┘
```

---

## 🚀 Quick start

Pré-requisitos: Docker. Em produção, VPS com portas 1883 + 9001 abertas no firewall.

```bash
# Clone (do parent ou direto)
git clone git@github.com:0xFelipeGD/Mosquitto-CEROS-MQTT-BROKER.git
cd Mosquitto-CEROS-MQTT-BROKER

# One-command wizard (prompts for password)
./wizard.sh

# OR manual:
CEROS_PWD=mypassword ./init.sh
./deploy.sh up
./deploy.sh status
```

---

## 📂 Estrutura

```
Mosquitto-CEROS-MQTT-BROKER/
├── README.md
├── docker-compose.yml      ← Mosquitto service
├── wizard.sh               ← one-command interactive install
├── init.sh                 ← generate passwd file (one-time)
├── deploy.sh               ← up/down/restart/logs/status
└── mosquitto/
    ├── mosquitto.conf      ← config (listeners 1883 + 9001)
    ├── acl                 ← user `ceros` → `ceros/#`
    └── passwd              ← password file (criado por init.sh)
```

---

## 🔒 Segurança em F2

- Username/password apenas — **sem TLS**. Aceitável em rede privada VPS ou para dev. Para produção pública, F10 vai adicionar TLS + certs Let's Encrypt + ACL granular.
- O password do `ceros` user é definido pelo wizard ou env var `CEROS_PWD=`.

---

## 🧪 Testing

```bash
# Subscribe ao tópico de odometria:
docker run --rm -it eclipse-mosquitto:2.0 mosquitto_sub \
  -h <BROKER_IP> -p 1883 \
  -u ceros -P <password> \
  -t 'ceros/odom'

# Publicar um cmd_vel:
docker run --rm -it eclipse-mosquitto:2.0 mosquitto_pub \
  -h <BROKER_IP> -p 1883 \
  -u ceros -P <password> \
  -t ceros/cmd_vel \
  -m '{"linear":{"x":0.3,"y":0,"z":0},"angular":{"x":0,"y":0,"z":0.2}}'
```

---

## 🪪 License

Proprietary. Felipe @0xFelipeGD.
