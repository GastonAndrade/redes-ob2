#!/bin/bash
# Obligatorio 2, parte 1.2: verifica adyacencias OSPF y captura los mensajes de arranque.
# Se corre DENTRO de la VM:  bash /media/sf_ob2/entrega/1_2-ospf/capturar-ospf.sh
# Si el lab ya esta levantado en ~/ospf12:  SOLO_CAPTURA=1 bash .../capturar-ospf.sh
# Deja los resultados en /media/sf_ob2/capturas/ (ospf_vecinos.txt, ospf_estado_r3.txt, ospf_arranque_r3.pcap)
# Nota: "kathara exec" falla si el comando lleva el argumento -c; por eso se usa "vtysh -e".

SRC=/media/sf_ob2/entrega/1_2-ospf
OUT=/media/sf_ob2/capturas
WORK=$HOME/ospf12
ROUTERS="r1 r2 r3 r4 r5 r6"

if [ -z "$SOLO_CAPTURA" ]; then
  echo "[1/5] Copiando el lab a $WORK y levantandolo..."
  kathara wipe -f >/dev/null 2>&1   # limpia contenedores de pruebas anteriores
  rm -rf "$WORK"; mkdir -p "$WORK"
  cp -r "$SRC"/. "$WORK"/
  rm -f "$WORK/capturar-ospf.sh"
  cd "$WORK" || exit 1
  mkdir -p shared
  kathara lstart --noterminals || { echo "ERROR: no levanto el lab"; exit 1; }
  echo "[2/5] Esperando 80 s a que OSPF forme las adyacencias..."
  sleep 80
else
  echo "[1-2/5] Usando el lab que ya esta levantado en $WORK"
  cd "$WORK" || exit 1
  mkdir -p shared
fi

echo "[3/5] Vecinos OSPF de cada router (esperado: todos en Full)"
: > "$OUT/ospf_vecinos.txt"
for r in $ROUTERS; do
  { echo "=== $r: show ip ospf neighbor"; kathara exec $r -- vtysh -e "show ip ospf neighbor" 2>&1; echo; } | tee -a "$OUT/ospf_vecinos.txt"
done

echo "[4/5] Captura de arranque en r3: empiezo tcpdump y reinicio FRR en r3..."
rm -f shared/ospf_arranque_r3.pcap
timeout 120 kathara exec r3 -- tcpdump -i any -n -Z root -U -w /shared/ospf_arranque_r3.pcap ip proto 89 >/dev/null 2>&1 &
sleep 5
timeout 30 kathara exec r3 -- systemctl restart frr
echo "     esperando 60 s a que r3 vuelva a formar las adyacencias..."
sleep 60
timeout 30 kathara exec r3 -- pkill tcpdump
sleep 3

echo "[5/5] Estado de OSPF en r3 y copia de archivos..."
{
  echo "=== r3: show ip ospf neighbor";  timeout 30 kathara exec r3 -- vtysh -e "show ip ospf neighbor"
  echo; echo "=== r3: show ip ospf database"; timeout 30 kathara exec r3 -- vtysh -e "show ip ospf database"
  echo; echo "=== r3: show ip ospf route";    timeout 30 kathara exec r3 -- vtysh -e "show ip ospf route"
} 2>&1 | tee "$OUT/ospf_estado_r3.txt"

if [ -s shared/ospf_arranque_r3.pcap ]; then
  cp shared/ospf_arranque_r3.pcap "$OUT/ospf_arranque_r3.pcap"
  echo; echo "=== Mensajes OSPF capturados (tipo y cantidad)"
  tcpdump -nr "$OUT/ospf_arranque_r3.pcap" 2>/dev/null | grep -o 'OSPFv2, [A-Za-z ]*' | sort | uniq -c
else
  echo "AVISO: no se genero el pcap en shared/. Revisar si tcpdump existe en r3."
fi
echo; echo "LISTO. Archivos en $OUT. El lab sigue levantado (kathara lclean para bajarlo)."
