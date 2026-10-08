#!/bin/sh

# Instala as dependências necessárias no Alpine Linux (iptables para firewall, iproute2 para rede)
apk add --no-cache iptables iproute2

# LIMPEZA (FLUSH)
# Apaga todas as regras pré-existentes para garantir que começamos do zero e não há conflito com regras que o Docker cria automaticamente.
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# POLÍTICA PADRÃO (ZERO TRUST)
# INPUT e OUTPUT referem-se ao tráfego direcionado AO próprio firewall. Aceitamos.
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT

# FORWARD é o tráfego que "atravessa" o firewall de uma rede para a outra.
# Definimos como DROP (Bloquear). Isto significa: "Se não houver uma regra 
# explícita a permitir, o pacote morre aqui."
iptables -P FORWARD DROP

# REGRAS DE ESTADO E TRADUÇÃO DE REDE (NAT)
# Permite que conexões já abertas de forma legítima recebam os pacotes de volta.
# Se o cliente pediu a página Web, o servidor Web tem de conseguir enviar a resposta.
iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# O MASCARAMENTO (NAT) foi a correção que fizemos. Ele camufla o IP do cliente (192.168.10.10) 
# e substitui pelo IP do Firewall (172.20.0.254) quando o pacote entra na DMZ. 
# Assim, os servidores da DMZ sabem como devolver a resposta sem se perderem na rede do Docker.
iptables -t nat -A POSTROUTING -s 192.168.10.0/24 -d 172.20.0.0/24 -j MASQUERADE

# REGRAS DE NEGÓCIO (BLACK E WHITE LIST)
# LIBERAÇÃO (ACCEPT): Permite que a rede Cliente (origem -s) aceda ao servidor Nginx na DMZ (destino -d) utilizando o protocolo TCP apenas na porta 80 (HTTP). 
iptables -A FORWARD -s 192.168.10.0/24 -d 172.20.0.10 -p tcp --dport 80 -j ACCEPT

# BLOQUEIO EXPLÍCITO (DROP): Impede categoricamente que a rede Cliente alcance o Banco de Dados.
# NOTA: Embora a Política Padrão já vá bloquear isto (porque não libertámos), isso e apenas redundancia
iptables -A FORWARD -s 192.168.10.0/24 -d 172.20.0.20 -p tcp --dport 5432 -j DROP

# Como é um script de configuração rápida, o container desliga-se no fim o 'tail -f /dev/null' força o script a ficar bloqueado num ciclo infinito, mantendo o container do firewall ligado indefinidamente a proteger a rede.
tail -f /dev/null

