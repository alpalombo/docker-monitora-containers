#!/bin/bash

# Versao: 6 - Atualizado em 2026-08-21 - Renomeado para monitora-containers.sh e adicionado monitoramento de memoria (%) e uso de memoria (MiB/GiB) por container

# ============================================================
# 1. Detecta automaticamente a quantidade de núcleos virtuais
# ============================================================
TOTAL_CORES=$(nproc)
echo "Núcleos virtuais detectados no servidor: $TOTAL_CORES"
echo ""

# ============================================================
# 2. Lista os containers em execução e pergunta quais monitorar
# ============================================================
mapfile -t CONTAINERS_DISPONIVEIS < <(docker ps --format "{{.Names}}")

if [ ${#CONTAINERS_DISPONIVEIS[@]} -eq 0 ]; then
    echo "Nenhum container em execução foi encontrado. Encerrando."
    exit 1
fi

echo "Containers em execução encontrados:"
for i in "${!CONTAINERS_DISPONIVEIS[@]}"; do
    printf "  [%d] %s\n" "$((i+1))" "${CONTAINERS_DISPONIVEIS[$i]}"
done
echo ""

read -p "Digite os números dos containers que deseja monitorar (separados por vírgula, ex: 1,3): " SELECAO

# Converte a seleção em um array com os nomes dos containers escolhidos
IFS=',' read -ra INDICES <<< "$SELECAO"
CONTAINERS_SELECIONADOS=()
for idx in "${INDICES[@]}"; do
    idx_trim=$(echo "$idx" | xargs)  # remove espaços
    pos=$((idx_trim-1))
    if [ "$pos" -ge 0 ] && [ "$pos" -lt "${#CONTAINERS_DISPONIVEIS[@]}" ]; then
        CONTAINERS_SELECIONADOS+=("${CONTAINERS_DISPONIVEIS[$pos]}")
    else
        echo "Aviso: opção '$idx_trim' inválida, ignorada."
    fi
done

if [ ${#CONTAINERS_SELECIONADOS[@]} -eq 0 ]; then
    echo "Nenhum container válido selecionado. Encerrando."
    exit 1
fi

echo ""
echo "Containers selecionados para monitoramento:"
printf '  - %s\n' "${CONTAINERS_SELECIONADOS[@]}"
echo ""

# ============================================================
# 3. Pergunta a duração do monitoramento
# ============================================================
read -p "Por quantas horas deseja monitorar? (ex: 1, 8, 24): " HORAS

# Valida se é um número (aceita decimais, ex: 0.5)
if ! [[ "$HORAS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Valor inválido. Encerrando."
    exit 1
fi

DURATION=$(awk -v h="$HORAS" 'BEGIN { printf "%.0f", h * 3600 }')
echo ""
echo "Monitoramento configurado para $HORAS hora(s) (= $DURATION segundos)."
echo ""

# ============================================================
# 4. Configurações gerais
# ============================================================
LOGFILE="$HOME/cpu_mem_monitor_$(date +%Y%m%d).log"
INTERVAL=30
END=$((SECONDS+DURATION))

# Monta o cabeçalho dinamicamente, com base nos containers selecionados
HEADER="timestamp;cpu_servidor(%)"
for c in "${CONTAINERS_SELECIONADOS[@]}"; do
    NOME_LIMPO=$(echo "$c" | tr -c 'A-Za-z0-9' '_')
    HEADER="$HEADER;cpu_${NOME_LIMPO}_docker(%);cpu_${NOME_LIMPO}_relativo_total(%);mem_${NOME_LIMPO}(%);mem_${NOME_LIMPO}_uso"
done

if [ ! -f "$LOGFILE" ]; then
    echo "$HEADER" >> "$LOGFILE"
fi

echo "Iniciando monitoramento. Log sendo gravado em: $LOGFILE"
echo "Pressione Ctrl+C para interromper manualmente a qualquer momento."
echo ""

# ============================================================
# 5. Loop de coleta
# ============================================================
while [ $SECONDS -lt $END ]; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    # CPU do servidor via mpstat (média de todos os núcleos, 1 amostra de 1 segundo)
    CPU_SERVER=$(mpstat 1 1 | awk '/Average/ {print 100 - $NF}')

    LINHA="$TIMESTAMP;$CPU_SERVER"

    for c in "${CONTAINERS_SELECIONADOS[@]}"; do
        # Pega CPU%, Mem% e Uso de memória (ex: "123.4MiB / 15.6GiB") em uma única chamada, separados por "|"
        STATS=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemPerc}}|{{.MemUsage}}" "$c" 2>/dev/null)

        CPU_RAW=$(echo "$STATS" | cut -d'|' -f1 | tr -d '%')
        MEM_PERC=$(echo "$STATS" | cut -d'|' -f2 | tr -d '%')
        MEM_USAGE=$(echo "$STATS" | cut -d'|' -f3 | tr -d ' ')

        if [ -z "$CPU_RAW" ]; then CPU_RAW="0"; fi
        if [ -z "$MEM_PERC" ]; then MEM_PERC="0"; fi
        if [ -z "$MEM_USAGE" ]; then MEM_USAGE="N/A"; fi

        CPU_REL=$(echo "$CPU_RAW / $TOTAL_CORES" | bc -l | xargs printf "%.2f")

        LINHA="$LINHA;$CPU_RAW;$CPU_REL;$MEM_PERC;$MEM_USAGE"
    done

    echo "$LINHA" >> "$LOGFILE"

    sleep "$INTERVAL"
done

echo "Monitoramento finalizado após $HORAS hora(s)."
