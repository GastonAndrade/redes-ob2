Obligatorio 2 - Redes de Computadoras 2026 - Grupo 27
=====================================================

Autores: Álvaro Ahunchain, Gastón Andrade, Franco Rivero

Cada carpeta es un laboratorio de Kathará independiente. Para levantar uno
hay que entrar a su carpeta y correr:

    kathara lstart       (levanta el laboratorio)
    kathara lclean       (lo detiene y borra los equipos)

Antes de levantar otro laboratorio conviene correr kathara lclean (o
kathara wipe -f) para no mezclar equipos de pruebas anteriores.


Carpetas
--------

parte1     Parte 1.1. Backbone r1 a r6 con los clientes A y B, numeración,
           NAT y rutas estáticas.
parte1_2   Parte 1.2 y 1.3. Lo mismo con OSPF configurado. Las pruebas de
           convergencia de la 1.3 también se hicieron sobre este laboratorio.
parte1_4   Parte 1.4. La red anterior con los routers r7 y r8 y el cliente C.
parte1_5   Parte 1.5. La red de la 1.4 con los costos OSPF de la 1.5.
parte2_1   Parte 2.1. LAN del cliente A con la numeración nueva y los switches
           P4 todavía sin programar (se usó para capturar el ARP).
parte2_2   Parte 2.2. Switch P4 con tabla MAC estática y contadores.
parte2_3   Parte 2.3. Se agrega la política de INVITADOS en p4sw3.
parte2_4   Parte 2.4. Se agrega port security en los switches.
parte3     Parte 3. Integración: el ISP ampliado con los clientes A, B y C.


Cosas a tener en cuenta
-----------------------

- En los laboratorios con OSPF hay que esperar un minuto o dos después de
  levantarlos para que se formen las adyacencias.
- En las carpetas parte2_x y parte3 cada switch tiene su switch.p4 y su
  commands.txt. Al arrancar, el .startup compila el programa y carga el
  commands.txt, así que no hace falta hacer nada a mano.
- La parte 3 levanta unos 33 equipos. En nuestras pruebas funcionó con una
  máquina virtual de 4 GB de RAM.
- Los resultados de las pruebas (pcaps, salidas de comandos, contadores) están
  en la carpeta shared/ o capturas/ de cada laboratorio. Lo que se levanta
  desde shared/ dentro de los equipos es lo mismo que aparece en el informe.
- parte1_2/capturar-ospf.sh y parte1_5/medir-1.5.sh son los scripts con los que
  tomamos las capturas de OSPF y de la 1.5. Tienen rutas de la máquina virtual
  de uno de nosotros, por lo que hay que ajustar SRC y OUT al correrlos.


Cómo probar
-----------

Las pruebas de cada parte están descritas en el informe (Obligatorio2Grupo27.pdf),
con los comandos usados. Para entrar a un equipo del laboratorio:

    kathara connect <equipo>        (por ejemplo: kathara connect pca1)

Para ver el estado de OSPF en un router:

    kathara connect r1
    vtysh -c "show ip ospf neighbor"
    vtysh -c "show ip route"

Para consultar los contadores de un switch P4:

    kathara connect p4sw3
    simple_switch_CLI
