# Instruções para Fork e Contribuição

## **Passo 1: Criar Fork no GitHub**

1. **Acesse o repositório original**: https://github.com/lMuchl/plugin_openkore_aiChat
2. **Clique no botão "Fork"** (canto superior direito)
3. **Escolha sua conta** para criar o fork
4. **Aguarde** a criação do fork

## **Passo 2: Configurar Remotes Locais**

Após criar o fork, execute estes comandos:

```bash
# Verificar remotes atuais
git remote -v

# Se necessário, configurar o fork como origin
git remote set-url origin https://github.com/SEU_USUARIO/plugin_openkore_aiChat.git

# Verificar se está funcionando
git remote -v
```

## **Passo 3: Fazer Push para o Fork**

```bash
# Fazer push para seu fork
git push origin main

# Verificar se foi enviado
git log --oneline -3
```

## **Passo 4: Criar Pull Request**

1. **Acesse seu fork** no GitHub
2. **Clique em "Compare & pull request"**
3. **Descreva as melhorias** implementadas
4. **Crie o Pull Request**

## **Estrutura dos Remotes**

- **upstream**: Repositório original (lMuchl/plugin_openkore_aiChat)
- **origin**: Seu fork (SEU_USUARIO/plugin_openkore_aiChat)

## **Comandos Úteis**

```bash
# Atualizar com o repositório original
git fetch upstream
git merge upstream/main

# Fazer push para seu fork
git push origin main

# Ver status
git status
git log --oneline -5
```

## **Resumo das Melhorias Implementadas**

**Sistema de Cache Inteligente**  
**Sistema de Fallback Robusto**  
**Gerenciamento de Contexto Inteligente**  
**Sistema de Logging Estruturado**  
**Configuração Centralizada**  
**Scripts de Automação**  
**Testes Automatizados**  
**Documentação Completa**  

**Total**: 17 arquivos, 3.414 inserções, 77 deleções
