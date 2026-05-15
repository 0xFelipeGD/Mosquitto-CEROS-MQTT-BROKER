# Mosquitto-CEROS-MQTT-BROKER

MQTT broker (Eclipse Mosquitto 2.0) + TURN server (coturn) para o twin ROS 2 do **CEROS** rover.

**Deploy só em Phase 8** (modo "remote via Internet"). Em Phases 1-7 o operador está na mesma rede do rover e usa DDS direto — este broker não é necessário.

Submódulo do parent [ROS2-RCS](https://github.com/0xFelipeGD/ROS2-RCS).

[![Mosquitto](https://img.shields.io/badge/Mosquitto-2.0-660066)]() [![coturn](https://img.shields.io/badge/coturn-latest-blue)]() [![TLS](https://img.shields.io/badge/TLS-1.2%2B-green)]() [![Phase](https://img.shields.io/badge/phase-8-grey)]()

---

## 📐 O que faz

- **Mosquitto MQTT broker (port 8883 TLS)**: relay de mensagens ROS 2 ↔ MQTT entre rover CEROS e operador remoto. Usado pelo `mqtt_client` (Bosch) na Jetson e pelo `mqtt.js` no Electron RCS-ROS2-CEROS.
- **coturn TURN server (3478 + 49152-65535 UDP)**: TURN relay pra WebRTC quando NAT impede P2P direto. Usado pelo aiortc do rover e WebRTC do browser.

```
        ┌────────────────────────────────────┐
        │  VPS (Mosquitto-CEROS-MQTT-BROKER)  │
        │                                    │
        │  ┌─────────────┐  ┌──────────────┐ │
        │  │ Mosquitto   │  │ coturn       │ │
        │  │ 1883 / 8883 │  │ 3478 / TURN  │ │
        │  │ 9001 (WS)   │  │              │ │
        │  └─────────────┘  └──────────────┘ │
        └────────────────────────────────────┘
                  ↑                ↑
                  │ MQTT/TLS      │ WebRTC video
                  │                │
   ┌───────────┐   ↓                ↓    ┌───────────┐
   │  CEROS   │ ←─────────────────────→  │ OPERADOR  │
   │  Jetson   │                          │ Electron  │
   └───────────┘                          └───────────┘
```

---

## 🚀 Quick start (quando chegar Phase 8)

Pré-requisitos: VPS com Docker, domínio DNS apontado pro IP da VPS, portas 8883/3478/49152-65535 abertas no firewall.

```bash
# Clone (do parent ou direto)
git clone git@github.com:0xFelipeGD/Mosquitto-CEROS-MQTT-BROKER.git
cd Mosquitto-CEROS-MQTT-BROKER

# Init (gera certs auto-assinados + password file). Apenas a primeira vez.
./init.sh

# Editar passwords antes de produção!
nano mosquitto/passwd  # ou regenerar com env vars

# Editar coturn relay-ip pra IP público da VPS
nano coturn/turnserver.conf

# Deploy
./deploy.sh up

# Verificar
./deploy.sh status
./deploy.sh logs
```

---

## 📂 Estrutura

```
Mosquitto-CEROS-MQTT-BROKER/
├── README.md
├── docker-compose.yml      ← Mosquitto + coturn services
├── init.sh                 ← gera certs auto-assinados + password file (one-time)
├── deploy.sh               ← deploy launcher (up/down/restart/logs/status)
├── mosquitto/
│   ├── mosquitto.conf      ← config Mosquitto (3 listeners: 1883, 8883 TLS, 9001 WS)
│   ├── acl                 ← ACL por user/topic (rcs_operator, ugv_client, health)
│   └── passwd              ← password file (criado por init.sh)
├── coturn/
│   └── turnserver.conf     ← config coturn (TURN/STUN/TLS)
├── certs/                  ← certs TLS (criado por init.sh)
└── scripts/                ← utilitários extras
```

---

## 🔒 Segurança

- **TLS obrigatório** na porta pública (8883). Plaintext só na 1883 que deve estar atrás de firewall.
- **3 users com ACL granular**:
  - `rcs_operator` — publica `/cmd_vel`, `/heartbeat`, etc.; lê telemetria
  - `ugv_client` (Jetson do CEROS) — publica telemetria; lê `/cmd_vel`
  - `health` — read-only `$SYS/#` pra healthcheck
- **Passwords**: editar `mosquitto/passwd` antes de produção (init.sh gera defaults inseguros)
- **Certs**: init.sh gera auto-assinados (OK pra dev/private use). Pra produção, usar Let's Encrypt

---

## 🧪 Testing

```bash
# Pub manual:
docker run --rm -it eclipse-mosquitto:2.0 mosquitto_pub \
  -h <VPS_IP> -p 8883 --cafile certs/ca.crt \
  -u rcs_operator -P <password> \
  -t ugv/test -m "hello"

# Sub manual:
docker run --rm -it eclipse-mosquitto:2.0 mosquitto_sub \
  -h <VPS_IP> -p 8883 --cafile certs/ca.crt \
  -u ugv_client -P <password> \
  -t ugv/#
```

---

## 🪪 License

Proprietary. Felipe @0xFelipeGD.
