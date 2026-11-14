# Obligatorio 2 – 2026 · Laboratorios base (Kathará)

Configuraciones iniciales para el Obligatorio 2 de Redes de Computadoras.
Cada carpeta es un laboratorio Kathará independiente:

| Carpeta | Contenido | Partes |
|---|---|---|
| `parte1/` | Backbone inicial de RíoNet (r1–r6), rint/pcint, Cliente A y Cliente B | 1.1, 1.2, 1.3, 1.5 |
| `parte1_4/` | Igual a `parte1/` más los routers r7 y r8, **sin enlaces ni direccionamiento** | 1.4 |
| `parte1_5/` | La red de la 1.4 ya resuelta (r7, r8, rclC) con los **costos OSPF de la 1.5** | 1.5 |
| `parte2/` | LAN del Cliente A con los switches P4 | 2.1 – 2.4 |

La Parte 3 (integración) se construye como un laboratorio nuevo a partir de los anteriores.

Para levantar un laboratorio, desde su carpeta:

```bash
kathara lstart      # levantar
kathara lclean      # detener y borrar
```

> Kathará solo admite minúsculas, dígitos y `_` en los nombres de dispositivo.
> Por eso los equipos del enunciado se llaman aquí `rint`, `rcla`, `rclb`,
> `pca1`, `pcb1`, `srvb`, `pc_admin1`, etc.

---

## Parte 1 – Backbone de RíoNet

Topología de la Figura 2 del enunciado. Enlaces:

- Internet: `rint–pcint` (INET), `rint–r1`, `rint–r6`
- Backbone: `r1–r2`, `r1–r3`, `r2–r3`, `r2–r4`, `r2–r5`, `r3–r5`, `r4–r5`, `r4–r6`, `r5–r6`
- Clientes: `r3–rcla`, `r5–rclb`; LAN_A (`rcla–pca1`), LAN_B (`rclb–pcb1`), DMZ_B (`rclb–srvb`)

Cada enlace `X–Y` del backbone es el dominio de colisión `X_Y` (por ejemplo `R2_R4`).

| Dispositivo | Imagen | eth0 | eth1 | eth2 | eth3 | eth4 |
|---|---|---|---|---|---|---|
| rint  | kathara/base | INET | RINT_R1 | RINT_R6 | | |
| pcint | kathara/base | INET | | | | |
| r1 | kathara/frr | RINT_R1 | R1_R2 | R1_R3 | | |
| r2 | kathara/frr | R1_R2 | R2_R3 | R2_R4 | R2_R5 | |
| r3 | kathara/frr | R1_R3 | R2_R3 | R3_R5 | R3_RCLA | |
| r4 | kathara/frr | R2_R4 | R4_R5 | R4_R6 | | |
| r5 | kathara/frr | R2_R5 | R3_R5 | R4_R5 | R5_R6 | R5_RCLB |
| r6 | kathara/frr | RINT_R6 | R4_R6 | R5_R6 | | |
| rcla | kathara/base | R3_RCLA | LAN_A | | | |
| pca1 | kathara/base | LAN_A | | | | |
| rclb | kathara/base | R5_RCLB | LAN_B | DMZ_B | | |
| pcb1 | kathara/base | LAN_B | | | | |
| srvb | kathara/base | DMZ_B | | | | |

Qué viene configurado:
- **pca1** (único host del Cliente A): `192.168.100.10/24`, gateway `192.168.100.1`.
  El resto del direccionamiento debe ser diseñado y configurado por el grupo.
- **r1–r6**: FRR se inicia en el `.startup` con el demonio `ospfd` habilitado
  (`rN/etc/frr/daemons`). El archivo `rN/etc/frr/frr.conf` está vacío y debe ser
  completado por el grupo. Consola del router: `vtysh`.
- **srvb**: servidor web Apache (HTTP) iniciado.
- **rint, rcla, rclb**: `kathara/base` (Linux). Las rutas estáticas y el NAT
  (`iptables`, ver Anexo 1) se configuran en sus `.startup`.

### Parte 1.4 – `parte1_4/`
Igual a `parte1/`, más `r7` y `r8` (`kathara/frr`, con ospfd habilitado y
`frr.conf` vacío). Se declaran en `lab.conf` sin interfaces: el grupo debe
agregar los enlaces, la nueva LAN de cliente en r8 y el direccionamiento.

### Parte 1.5 – `parte1_5/`
Es la red de la parte 1.4 (con r7, r8 y rclC) más el cambio de costos OSPF que
fija el camino principal entre r1 y r6: **r1 – r2 – r4 – r6** (costo 10), con
respaldo **r1 – r3 – r5 – r6** (costo 11). Lo único que cambia respecto de `parte1_4/`
son seis líneas `ip ospf cost` (más el nombre del lab en `lab.conf`):

| Enlace | Interfaces | Costo en 1.4 | Costo en 1.5 |
|---|---|---|---|
| r2–r4 | r2 eth2 · r4 eth0 | 5 | **1** |
| r4–r6 | r4 eth2 · r6 eth1 | 5 | **4** |
| r2–r5 | r2 eth3 · r5 eth0 | 1 | **2** |

Con eso r1–r2–r5–r6 pasa a costar 12 y ya no empata con el respaldo (11).

Para comprobarlo: `kathara lstart`, esperar las adyacencias y, en r1,
`vtysh -c "show ip route 10.100.0.6"` (sale por eth1, métrica 20) y
`traceroute -n -s 10.100.0.2 10.100.0.6` (pasa por 10.100.0.14 y 10.100.0.18).
Para provocar la falla: en r2 `ip link set eth2 down`; r1 pasa a salir por eth2
(métrica 21, vía 10.100.0.22 y 10.100.0.37). Se restaura con `ip link set eth2 up`.

`capturas/` tiene las evidencias de esa prueba: `falla_r1_eth1/eth2.pcap` y
`vuelta_r1_eth1/eth2.pcap` (tcpdump en r1), los `ping_*.txt`, `antes_/despues_/restaurado_`
con rutas y traceroute de r1 y r6, y los costos por router. Se tomaron el 5–6/11 con
`medir-1.5.sh` (corre dentro de la VM; los paths son los de la carpeta compartida de la VM).
Esa corrida es anterior al cambio de numeración de la LAN C (rclC): no afecta a la 1.5
porque el camino r1–r6 no pasa por esa zona.

---

## Parte 2 – LAN del Cliente A con switches P4

```
                 ┌── p4sw1 ── pc_admin1, pc_admin2, pc_admin3, pc_admin4
                 │
rcla (gateway) ──┼── p4sw2 ── pc_dev1, pc_dev2, pc_dev3
                 │
                 ├── p4sw3 ── pc_guest1, pc_guest2, pc_guest3
                 │
                 └── p4sw4 ── srv1 (HTTP/HTTPS)
```

| Dispositivo | Imagen | Interfaces (dominio de colisión) |
|---|---|---|
| rcla | kathara/base | eth0 RCLA_SW1 · eth1 RCLA_SW2 · eth2 RCLA_SW3 · eth3 RCLA_SW4 |
| p4sw1 | kathara/p4 | eth0 RCLA_SW1 · eth1–eth4 SW1_ADMIN1–4 |
| p4sw2 | kathara/p4 | eth0 RCLA_SW2 · eth1–eth3 SW2_DEV1–3 |
| p4sw3 | kathara/p4 | eth0 RCLA_SW3 · eth1–eth3 SW3_GUEST1–3 |
| p4sw4 | kathara/p4 | eth0 RCLA_SW4 · eth1 SW4_SRV1 |
| pc_admin1–4 | kathara/base | eth0 SW1_ADMIN1–4 |
| pc_dev1–3 | kathara/base | eth0 SW2_DEV1–3 |
| pc_guest1–3 | kathara/base | eth0 SW3_GUEST1–3 |
| srv1 | kathara/base | eth0 SW4_SRV1 |

`pc_admin4` es el host adicional para la **Reflexión 2.2**. Está conectado a p4sw1,
pero la idea es que no se incluya en la configuración del switch.

Ningún host tiene dirección IP: la numeración es parte del Entregable 2.1.
**srv1** inicia Apache con HTTP (80) y HTTPS (443, certificado autofirmado).

### Switches P4

Cada `p4swN/` contiene:
- `switch.p4`: **esqueleto** del programa. Define el encabezado Ethernet, el
  parser y el deparser. Ingress y egress están vacíos (`TODO`).
- `commands.txt`: configuración del plano de control (vacío). Cada línea es un
  comando de `simple_switch_CLI` (por ejemplo `table_add ...`), y se aplica al
  iniciar el switch.

El `.startup` de cada switch compila `switch.p4`, inicia el switch P4 (BMv2 `simple_switch`)
y carga `commands.txt`. Puertos P4 ↔ interfaces:

| Puerto P4 | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| Interfaz | eth0 (hacia rcla) | eth1 | eth2 | eth3 | eth4 (solo p4sw1) |

Dentro de un switch:

```bash
cat /var/log/simple_switch.log     # log de BMv2 (incluye errores de compilación/arranque)
simple_switch_CLI                  # CLI interactiva (help, table_dump, counter_read, ...)
```

Para aplicar cambios en `switch.p4` o `commands.txt`: `kathara lrestart`.
