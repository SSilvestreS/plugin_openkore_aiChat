# Plugin AI Chat para OpenKore

Este plugin integra o OpenKore com modelos de Linguagem de IA, permitindo que seu bot converse naturalmente com outros jogadores, mantendo o contexto e utilizando informações do seu personagem (nome, classe, níveis, mapa).

## **Novas Funcionalidades (v2.0)**

### **Sistema de Cache Inteligente**
- **Cache em memória** com TTL configurável
- **Busca por similaridade** para respostas similares
- **Limpeza automática** de itens expirados
- **Evicção inteligente** de itens antigos
- **Estatísticas detalhadas** de performance

### **Sistema de Fallback Robusto**
- **Respostas pré-definidas** para situações de emergência
- **Retry automático** com backoff exponencial
- **Classificação inteligente** de mensagens
- **Contexto personalizado** nas respostas
- **Fallback por tipo** (saudação, ajuda, ocupado, erro)

### **Gerenciamento de Contexto Inteligente**
- **Detecção automática** de contexto (combate, leveling, trading, quest)
- **Estados dinâmicos** (idle, active, busy, danger)
- **Histórico de contexto** com eventos
- **Cálculo de urgência** baseado no estado
- **Adaptação automática** do comportamento

### **Sistema de Logging Estruturado**
- **Logs em JSON** e texto
- **Rotação automática** de arquivos
- **Logs separados** por tipo (main, error, performance)
- **Contexto rico** em cada entrada
- **Métricas de performance** integradas

## **Pré-requisitos e Instalação**

Para usar o plugin, você precisará:

*   **OpenKore**: Versão atual.
*   **Node.js**: V16.x+ ([nodejs.org](https://nodejs.org/)).
*   **Perl**: 5.20+ com módulos CPAN:
    ```bash
    cpan install LWP::UserAgent HTTP::Request JSON::Tiny Digest::MD5 Time::HiRes File::Path
    ```
*   **Pacotes Node.js**: Na pasta `plugins/aiChat`, execute:
    ```bash
    npm install
    ```

### **Instalação Rápida**

1. **Clone ou baixe** este repositório
2. **Execute o script de instalação**:
   ```bash
   cd aiChat
   install.bat
   ```
3. **Configure suas chaves de API** no arquivo `.env`
4. **Inicie o sistema**:
   ```bash
   start_openkore_e_proxy.bat
   ```

## **Configuração**

### **A. Configuração do Proxy Node.js**

Crie um arquivo `.env` baseado no `env.example`:

```env
# API Keys (escolha uma ou ambas)
DEEPSEEK_API_KEY=sua_chave_deepseek_aqui
OPENAI_API_KEY=sua_chave_openai_aqui

# Configurações do Servidor
PORT=3000
HOST=localhost

# Logging
LOG_LEVEL=info
ENABLE_DEBUG=false

# Rate Limiting
RATE_LIMIT_WINDOW=60000
RATE_LIMIT_MAX_REQUESTS=100

# Timeout
REQUEST_TIMEOUT=30000
```

### **B. Configuração do OpenKore**

No `control/config.txt` ou via console (`aichat set`):

*   `aiChat_provider`: `openai` ou `deepseek` (padrão: `deepseek`)
*   `aiChat_model`: `gpt-3.5-turbo` ou `deepseek-chat`
*   `aiChat_prompt`: Prompt que define o comportamento da IA
*   `aiChat_max_tokens`: Máx. tokens na resposta (padrão: `150`)
*   `aiChat_temperature`: Criatividade da IA (0.0-1.0, padrão: `0.6`)
*   `aiChat_typing_speed`: Velocidade de digitação (padrão: `20`)

## **Uso**

### **Inicialização**

1. **Execute o launcher principal**:
   ```bash
   start_openkore_e_proxy.bat
   ```
   
   Ou inicie apenas o proxy:
   ```bash
   start_proxy_only.bat
   ```

2. **No OpenKore**, carregue o plugin:
   ```
   plugins load aiChat
   ```

3. **Configure o provedor** (se necessário):
   ```
   aichat provider deepseek
   ```

### **Comandos Disponíveis**

*   `aichat help`: Mostra todos os comandos
*   `aichat status`: Status atual e informações do personagem
*   `aichat config`: Configurações atuais
*   `aichat set <chave> <valor>`: Define um valor
*   `aichat provider <openai|deepseek>`: Altera o provedor
*   `aichat cache stats`: Estatísticas do sistema de cache
*   `aichat context info`: Informações do contexto atual
*   `aichat fallback stats`: Estatísticas do sistema de fallback

## **Testes**

### **Executar Testes**

```bash
cd aiChat
run_tests.bat
```

### **Testes Disponíveis**

- **Cache Tests**: Sistema de cache e similaridade
- **Fallback Tests**: Sistema de fallback e retry
- **Context Tests**: Gerenciamento de contexto
- **Integration Tests**: Testes de integração

### **Requisitos para Testes**

```bash
cpan Test::More Test::MockTime
```

## **Arquitetura**

### **Módulos Principais**

```
AIChat/
├── Cache.pm              # Sistema de cache inteligente
├── FallbackManager.pm    # Sistema de fallback e retry
├── ContextManager.pm     # Gerenciamento de contexto
├── Logger.pm             # Sistema de logging estruturado
├── Config.pm             # Gerenciamento de configuração
├── APIClient.pm          # Cliente para APIs de IA
├── MessageHandler.pm     # Processamento de mensagens
├── ConversationHistory.pm # Histórico de conversas
└── HookManager.pm        # Gerenciamento de hooks
```

### **Fluxo de Processamento**

1. **Mensagem recebida** → `MessageHandler`
2. **Contexto atualizado** → `ContextManager`
3. **Cache verificado** → `Cache` (resposta similar?)
4. **API chamada** → `APIClient` (se não em cache)
5. **Fallback aplicado** → `FallbackManager` (se API falhar)
6. **Resposta enviada** → Usuário
7. **Logs registrados** → `Logger`

## **Monitoramento e Métricas**

### **Endpoint de Status**

```
GET http://localhost:3000/status
```

Retorna:
- Status do servidor
- Provedores disponíveis
- Configurações atuais
- Uptime e estatísticas

### **Logs Estruturados**

- **Logs principais**: `logs/aichat_YYYYMMDD.log`
- **Logs de erro**: `logs/aichat_errors_YYYYMMDD.log`
- **Logs de performance**: `logs/aichat_performance_YYYYMMDD.log`

### **Métricas Disponíveis**

- **Cache**: Hit rate, tamanho, evicções
- **Fallback**: Uso, sucessos de retry
- **Contexto**: Mudanças, duração, eventos
- **Performance**: Tempo de resposta, uso de memória

## **Solução de Problemas**

### **Problemas Comuns**

*   **`Error: listen EADDRINUSE: address already in use :::3000`**: 
    - Porta 3000 já em uso
    - Use `netstat -ano | findstr :3000` para encontrar o PID
    - Encerre o processo ou mude a porta no `.env`

*   **Erros de `Can't locate module...`**: 
    - Módulos Perl não instalados
    - Execute: `cpan install <modulo>`

*   **IA não responde**: 
    - Verifique se o proxy está rodando
    - Confirme as chaves de API no `.env`
    - Verifique os logs em `logs/`

*   **Cache não funcionando**: 
    - Verifique permissões de escrita
    - Use `aichat cache stats` para diagnóstico

### **Debug e Logs**

```bash
# Ativar debug
echo "ENABLE_DEBUG=true" >> .env

# Ver logs em tempo real
tail -f logs/aichat_*.log

# Verificar status do proxy
curl http://localhost:3000/status
```

## **Contribuindo**

### **Como Contribuir**

1. **Fork** o repositório
2. **Crie uma branch** para sua feature
3. **Implemente** com testes
4. **Execute os testes**: `run_tests.bat`
5. **Faça um Pull Request**

### **Áreas para Contribuição**

- **Novos provedores de IA**
- **Algoritmos de similaridade** para cache
- **Padrões de contexto** adicionais
- **Métricas e monitoramento**
- **Interface web** de administração
- **Testes adicionais**

## **Licença**

MIT License - veja [LICENSE](LICENSE) para detalhes.

## **Agradecimentos**

- Comunidade OpenKore
- Contribuidores do projeto
- Usuários que testaram e reportaram bugs

---

**Versão**: 2.0.0  
**Última atualização**: Dezembro 2024  
**Compatibilidade**: OpenKore atual + Node.js 16+
