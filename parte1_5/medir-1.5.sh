#!/bin/bash
# NOTA: los paths /media/sf_ob2/... son los de la carpeta compartida de la VM de Franco; SRC y OUT hay que ajustarlos a donde este parte1_5.
# Parte 1.5: ingenieria de caminos entre r1 y r6. Se corre DENTRO de la VM.
#   bash /media/sf_ob2/entrega/1_5-ingenieria-caminos/medir-1.5.sh base    (costos sin cambiar)
#   bash /media/sf_ob2/entrega/1_5-ingenieria-caminos/medir-1.5.sh final   (costos nuevos + falla)
# Los resultados quedan en /media/sf_ob2/capturas/1_5/<fase>/
# Nota: "kathara exec" no acepta argumentos -c, por eso lo de adentro va en scripts de /shared.

FASE=$1
SRC=/media/sf_ob2/entrega/1_5-ingenieria-caminos
OUT=/media/sf_ob2/capturas/1_5/$FASE
WORK=$HOME/ob15
ROUTERS="r1 r2 r3 r4 r5 r6 r7 r8"
[ "$FASE" = base ] || [ "$FASE" = final ] || { echo "uso: $0 base|final"; exit 1; }

mkdir -p "$OUT"
exec > >(tee "$OUT/log.txt") 2>&1

ex() { timeout 60 kathara exec "$@" </dev/null; }

echo "[1] Levantando el lab ($(date +%T))"
kathara wipe -f >/dev/null 2>&1
rm -rf "$WORK"; mkdir -p "$WORK"
cp -r "$SRC"/. "$WORK"/
rm -f "$WORK/medir-1.5.sh"
cd "$WORK" || exit 1
mkdir -p shared

# --- Scripts que corren adentro de los equipos ---
cat > shared/foto.sh <<'EOF'
#!/bin/bash
# Estado de r1 o r6 hacia el otro extremo. $1 = etiqueta
H=$(hostname)
if [ "$H" = r1 ]; then ORI=10.100.0.2; DST=10.100.0.6; PRE=10.100.0.4/30
else ORI=10.100.0.6; DST=10.100.0.2; PRE=10.100.0.0/30; fi
{
  echo "=== $H: show ip route $DST"
  vtysh -c "show ip route $DST"
  echo "=== $H: ip route | grep $PRE"
  ip route | grep -A2 "^$PRE"
  echo "=== $H: traceroute -n -s $ORI $DST"
  traceroute -n -q 1 -w 2 -s $ORI $DST
} > /shared/$1_$H.txt 2>&1
EOF
cat > shared/costos.sh <<'EOF'
#!/bin/bash
H=$(hostname)
{ echo "=== $H"; vtysh -c "show ip ospf interface" | grep -E "^eth|Cost:"; } > /shared/costos_$H.txt 2>&1
EOF
cat > shared/traza.sh <<'EOF'
#!/bin/bash
# $1 = etiqueta, $2 = destino
H=$(hostname)
{ echo "=== $H -> $2"; traceroute -n -q 1 -w 2 $2; } > /shared/$1_${H}_$2.txt 2>&1
EOF
cat > shared/captura.sh <<'EOF'
#!/bin/bash
# $1 = interfaz, $2 = archivo
exec tcpdump -i $1 -n -U -Z root -w /shared/$2.pcap 'icmp or ip proto 89'
EOF
cat > shared/ping.sh <<'EOF'
#!/bin/bash
# $1 = archivo
exec ping -D -O -i 0.2 -I 10.100.0.2 10.100.0.6 > /shared/$1.txt 2>&1
EOF
cat > shared/enlace.sh <<'EOF'
#!/bin/bash
# $1 = up|down, marca el instante exacto del evento
date +%s.%N >> /shared/instantes.txt
echo "eth2 $1" >> /shared/instantes.txt
ip link set eth2 $1
EOF

kathara lstart --noterminals || { echo "ERROR: no levanto el lab"; exit 1; }

echo "[2] Esperando adyacencias (13 enlaces = 26 vecinos en Full)"
sleep 60
for i in $(seq 1 40); do
  n=0
  for r in $ROUTERS; do
    c=$(ex $r -- vtysh -e "show ip ospf neighbor" 2>/dev/null | grep -c Full)
    n=$((n+c))
  done
  echo "    vecinos en Full: $n/26 ($(date +%T))"
  [ "$n" -ge 26 ] && break
  sleep 10
done
sleep 15

: > "$OUT/vecinos.txt"
for r in $ROUTERS; do
  { echo "=== $r"; ex $r -- vtysh -e "show ip ospf neighbor"; echo; } >> "$OUT/vecinos.txt" 2>&1
done

echo "[3] Costos y estado inicial"
for r in r1 r2 r3 r4 r5 r6; do ex $r -- bash /shared/costos.sh; done
ex r1 -- bash /shared/foto.sh antes
ex r6 -- bash /shared/foto.sh antes
ex pca1 -- bash /shared/traza.sh clientes 8.8.8.8
ex pca1 -- bash /shared/traza.sh clientes 203.0.113.6
ex srvb -- bash /shared/traza.sh clientes 8.8.8.8
ex pcint -- bash /shared/traza.sh clientes 203.0.113.6

if [ "$FASE" = final ]; then
  echo "[4] Captura + ping + FALLA del enlace r2-r4 ($(date +%T))"
  ex r1 -- bash /shared/captura.sh eth1 falla_r1_eth1 >/dev/null 2>&1 &
  ex r1 -- bash /shared/captura.sh eth2 falla_r1_eth2 >/dev/null 2>&1 &
  sleep 5
  timeout 200 kathara exec r1 -- bash /shared/ping.sh ping_falla </dev/null >/dev/null 2>&1 &
  sleep 12
  ex r2 -- bash /shared/enlace.sh down
  echo "    enlace caido, espero 50 s (pasa el dead interval de r4)"
  sleep 50
  ex r1 -- pkill ping
  ex r1 -- pkill tcpdump
  sleep 3

  echo "[5] Estado con el enlace caido"
  ex r1 -- bash /shared/foto.sh despues
  ex r6 -- bash /shared/foto.sh despues

  echo "[6] Captura + ping + se levanta el enlace ($(date +%T))"
  ex r1 -- bash /shared/captura.sh eth1 vuelta_r1_eth1 >/dev/null 2>&1 &
  ex r1 -- bash /shared/captura.sh eth2 vuelta_r1_eth2 >/dev/null 2>&1 &
  sleep 5
  timeout 200 kathara exec r1 -- bash /shared/ping.sh ping_vuelta </dev/null >/dev/null 2>&1 &
  sleep 8
  ex r2 -- bash /shared/enlace.sh up
  echo "    enlace arriba, espero 65 s (se rearma la adyacencia)"
  sleep 65
  ex r1 -- pkill ping
  ex r1 -- pkill tcpdump
  sleep 3
  ex r1 -- bash /shared/foto.sh restaurado
  ex r6 -- bash /shared/foto.sh restaurado
fi

echo "[7] Copiando resultados a $OUT"
cp -r shared/. "$OUT"/
rm -f "$OUT"/*.sh
ls -la "$OUT"

if [ "$FASE" = base ]; then
  kathara lclean >/dev/null 2>&1
fi
echo "LISTO $FASE ($(date +%T))"
