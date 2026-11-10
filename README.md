# monitora-containers

Script em Bash para monitorar o uso de **CPU** e **memória** de containers Docker (e a CPU total do servidor) em um servidor Linux, gravando tudo em um arquivo de log no formato CSV (separador `;`).

## Funcionalidades

- Detecta automaticamente a quantidade de núcleos virtuais do servidor (`nproc`)
- Lista os containers em execução e pergunta quais você quer monitorar
- Pergunta por quantas horas o monitoramento deve rodar (aceita decimais, ex: `0.5`)
- Registra a cada 30 segundos:
  - CPU total do servidor (%)
  - CPU de cada container, no valor bruto do Docker (1 núcleo = 100%)
  - CPU de cada container relativa ao total do servidor (100% = todos os núcleos)
  - Memória de cada container (% e uso, ex: `450MiB/15.6GiB`)

## Requisitos

Testado no Ubuntu 24.04.

```bash
sudo apt update
sudo apt install sysstat bc screen -y
```

| Pacote | Para que serve |
|---|---|
| `docker` | Coleta das métricas dos containers (`docker stats`) |
| `sysstat` | Fornece o `mpstat`, usado para a CPU do servidor |
| `bc` | Cálculos de percentual |
| `screen` | Manter o script rodando sem prender o terminal |

O usuário que executa o script precisa ter permissão para usar o Docker (estar no grupo `docker`).

## Instalação

```bash
git clone https://github.com/SEU-USUARIO/monitora-containers.git
cd monitora-containers
chmod +x monitora-containers.sh
```

## Como executar sem travar o terminal

O script é **interativo** (faz perguntas), então ele **não deve** ser iniciado com `nohup ... &` diretamente, pois ficaria esperando respostas que nunca chegam. O jeito correto é usar o `screen`.

### 1. Abra uma sessão do screen

```bash
screen -S monitor
```

### 2. Execute o script dentro da sessão

```bash
./monitora-containers.sh
```

Responda às perguntas:

```
Digite os números dos containers que deseja monitorar (separados por vírgula, ex: 1,3): 1,2
Por quantas horas deseja monitorar? (ex: 1, 8, 24): 8
```

### 3. Saia da sessão sem interromper o script

Quando aparecer a mensagem `Iniciando monitoramento. Log sendo gravado em: ...`, pressione:

```
Ctrl+A, solte, e depois pressione D
```

O terminal é liberado (`[detached from ...monitor]`) e o script continua rodando em segundo plano, mesmo que você feche a conexão SSH.

### 4. Comandos úteis

```bash
screen -ls                      # lista as sessões ativas
screen -r monitor               # volta para a sessão do script
```

Para interromper o monitoramento antes do tempo, volte para a sessão (`screen -r monitor`) e pressione `Ctrl+C`.

## Acompanhar o log

```bash
tail -f $HOME/cpu_mem_monitor_$(date +%Y%m%d).log
```

Use `Ctrl+C` para sair do `tail` (isso não interrompe o monitoramento).

## Formato do log

Arquivo: `$HOME/cpu_mem_monitor_AAAAMMDD.log`

O cabeçalho é montado dinamicamente conforme os containers escolhidos. Exemplo com um container:

```
timestamp;cpu_servidor(%);cpu_meu_container_1_docker(%);cpu_meu_container_1_relativo_total(%);mem_meu_container_1(%);mem_meu_container_1_uso
2026-08-21 17:21:12;2;2.28;0.11;3.45;450MiB/15.6GiB
```

### Interpretando os valores de CPU

- **`docker(%)`**: base de 1 núcleo = 100%. Um valor de `150%` significa que o container usou 1,5 núcleo naquele instante. Em um servidor com 10 núcleos, o teto é `1000%`.
- **`relativo_total(%)`**: o valor acima dividido pela quantidade de núcleos do servidor. Aqui 100% significa que todos os núcleos estão saturados.

## Problemas comuns

**`Permission denied` ao executar**
Falta permissão de execução:
```bash
chmod +x monitora-containers.sh
```

**`No such file or directory` mesmo com o arquivo existindo**
O arquivo pode ter quebras de linha do Windows (CRLF):
```bash
sudo apt install dos2unix -y
dos2unix monitora-containers.sh
```

**`mpstat: command not found`**
```bash
sudo apt install sysstat -y
```

**Não rodar com `sudo`**
Rodar com `sudo` faz o processo ficar como root e o log pode ser gravado em outro `$HOME`. Use o seu usuário normal (que tenha acesso ao Docker).

**Mais de uma instância rodando ao mesmo tempo**
Para encerrar todas:
```bash
pkill -f monitora-containers.sh
```
Confirme com:
```bash
ps aux | grep monitora-containers.sh | grep -v grep
```

## Histórico de versões

A versão atual fica no comentário no topo do script (`# Versao: N`).

| Versão | Mudança |
|---|---|
| 6 | Renomeado para `monitora-containers.sh` e adicionado monitoramento de memória |
| 5 | Detecção automática de núcleos, seleção interativa de containers e duração customizável |
| 4 | Corrigido `TOTAL_CORES` para 20 núcleos |
| 3 | Adicionado segundo container |
