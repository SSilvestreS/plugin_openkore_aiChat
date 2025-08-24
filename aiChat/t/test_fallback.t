#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 20;
use Test::MockTime qw(set_fixed_time restore_time);

# Adiciona o diretório lib ao @INC
use lib 'AIChat';

# Mock do módulo Log para evitar dependências externas
BEGIN {
    package Log;
    sub debug { 1 }
    sub warning { 1 }
    sub error { 1 }
    $INC{'Log.pm'} = 1;
}

use AIChat::FallbackManager;

# Teste 1: Criação de instância
subtest "FallbackManager instance creation" => sub {
    my $fallback = AIChat::FallbackManager->new();
    isa_ok($fallback, 'AIChat::FallbackManager');
    is($fallback->{retry_count}, 0, 'Initial retry count should be 0');
    is($fallback->{last_retry_time}, 0, 'Initial last retry time should be 0');
};

# Teste 2: Verificação de retry
subtest "Retry checking" => sub {
    my $fallback = AIChat::FallbackManager->new();
    my $context = { map_name => 'prontera', base_level => 10 };
    
    # Primeira tentativa de retry
    my $should_retry = $fallback->shouldRetry('api_error', $context);
    is($should_retry, 1, 'Should allow first retry');
    
    # Segunda tentativa
    $should_retry = $fallback->shouldRetry('api_error', $context);
    is($should_retry, 1, 'Should allow second retry');
    
    # Terceira tentativa
    $should_retry = $fallback->shouldRetry('api_error', $context);
    is($should_retry, 1, 'Should allow third retry');
    
    # Quarta tentativa (deve falhar)
    $should_retry = $fallback->shouldRetry('api_error', $context);
    is($should_retry, 0, 'Should not allow fourth retry');
};

# Teste 3: Delay exponencial
subtest "Exponential backoff delay" => sub {
    my $fallback = AIChat::FallbackManager->new();
    my $context = { map_name => 'prontera' };
    
    set_fixed_time(1000);
    
    # Primeira tentativa
    $fallback->shouldRetry('api_error', $context);
    
    # Tenta imediatamente (deve falhar)
    my $immediate_retry = $fallback->shouldRetry('api_error', $context);
    is($immediate_retry, 0, 'Should not allow immediate retry');
    
    # Avança 1 segundo (deve permitir)
    set_fixed_time(1001);
    my $delayed_retry = $fallback->shouldRetry('api_error', $context);
    is($delayed_retry, 1, 'Should allow retry after 1 second');
    
    # Avança 2 segundos (deve permitir)
    set_fixed_time(1003);
    my $delayed_retry2 = $fallback->shouldRetry('api_error', $context);
    is($delayed_retry2, 1, 'Should allow retry after 2 seconds');
    
    restore_time();
};

# Teste 4: Registro de sucesso de retry
subtest "Retry success recording" => sub {
    my $fallback = AIChat::FallbackManager->new();
    my $context = { map_name => 'prontera' };
    
    # Faz algumas tentativas
    $fallback->shouldRetry('api_error', $context);
    $fallback->shouldRetry('api_error', $context);
    
    # Registra sucesso
    $fallback->recordRetrySuccess('api_error', $context);
    
    # Deve permitir nova tentativa
    my $new_retry = $fallback->shouldRetry('api_error', $context);
    is($new_retry, 1, 'Should allow new retry after success');
};

# Teste 5: Registro de falha de retry
subtest "Retry failure recording" => sub {
    my $fallback = AIChat::FallbackManager->new();
    my $context = { map_name => 'prontera' };
    
    # Faz algumas tentativas
    $fallback->shouldRetry('api_error', $context);
    $fallback->shouldRetry('api_error', $context);
    
    # Registra falha
    $fallback->recordRetryFailure('api_error', $context);
    
    # Deve permitir mais tentativas
    my $retry = $fallback->shouldRetry('api_error', $context);
    is($retry, 1, 'Should allow retry after failure');
};

# Teste 6: Respostas de fallback
subtest "Fallback responses" => sub {
    my $fallback = AIChat::FallbackManager->new();
    my $context = { map_name => 'prontera', base_level => 10 };
    
    # Testa resposta de saudação
    my $greeting = $fallback->getFallbackResponse("oi", $context);
    ok(defined $greeting, 'Should return greeting response');
    like($greeting, qr/^(oi|ae|fala|e ai|oi tudo bem)$/, 'Response should match greeting pattern');
    
    # Testa resposta de ajuda
    my $help = $fallback->getFallbackResponse("ajuda", $context);
    ok(defined $help, 'Should return help response');
    like($help, qr/(ajuda|ajudar|saber|precisa)/, 'Response should match help pattern');
    
    # Testa resposta de ocupado
    my $busy = $fallback->getFallbackResponse("ocupado", $context);
    ok(defined $busy, 'Should return busy response');
    like($busy, qr/(ocupado|upando|quest)/, 'Response should match busy pattern');
};

# Teste 7: Classificação de mensagens
subtest "Message classification" => sub {
    my $fallback = AIChat::FallbackManager->new();
    
    # Testa diferentes tipos de mensagem
    my $greeting_type = $fallback->_classifyMessage("oi");
    is($greeting_type, 'greeting', 'Should classify "oi" as greeting');
    
    my $help_type = $fallback->_classifyMessage("precisa de ajuda");
    is($help_type, 'help', 'Should classify help message correctly');
    
    my $busy_type = $fallback->_classifyMessage("to upando");
    is($busy_type, 'busy', 'Should classify busy message correctly');
    
    my $error_type = $fallback->_classifyMessage("deu erro");
    is($error_type, 'error', 'Should classify error message correctly');
    
    my $unknown_type = $fallback->_classifyMessage("mensagem estranha");
    is($unknown_type, 'unknown', 'Should classify unknown message correctly');
};

# Teste 8: Adição de contexto às respostas
subtest "Context addition to responses" => sub {
    my $fallback = AIChat::FallbackManager->new();
    
    # Contexto com mapa
    my $context_with_map = { map_name => 'prontera', base_level => 10 };
    my $response_with_map = $fallback->getFallbackResponse("oi", $context_with_map);
    like($response_with_map, qr/prontera/, 'Response should include map name');
    
    # Contexto com level
    my $context_with_level = { map_name => 'gef_fild01', base_level => 50 };
    my $response_with_level = $fallback->getFallbackResponse("to upando", $context_with_level);
    like($response_with_level, qr/level 50/, 'Response should include level');
    
    # Contexto vazio
    my $empty_context = {};
    my $response_empty = $fallback->getFallbackResponse("oi", $empty_context);
    unlike($response_empty, qr/mapa|level/, 'Response should not include context info');
};

# Teste 9: Estatísticas de fallback
subtest "Fallback statistics" => sub {
    my $fallback = AIChat::FallbackManager->new();
    my $context = { map_name => 'prontera' };
    
    # Usa algumas respostas de fallback
    $fallback->getFallbackResponse("oi", $context);
    $fallback->getFallbackResponse("ajuda", $context);
    
    my $stats = $fallback->getStats();
    
    is($stats->{fallback_responses_used}, 2, 'Should count fallback responses used');
    is($stats->{max_retries}, 3, 'Max retries should be 3');
    is($stats->{retry_delay_base}, 1, 'Retry delay base should be 1');
    is($stats->{retry_delay_multiplier}, 2, 'Retry delay multiplier should be 2');
};

# Teste 10: Limpeza de histórico
subtest "History clearing" => sub {
    my $fallback = AIChat::FallbackManager->new();
    my $context = { map_name => 'prontera' };
    
    # Faz algumas tentativas
    $fallback->shouldRetry('api_error', $context);
    $fallback->shouldRetry('api_error', $context);
    
    # Limpa histórico
    $fallback->clearRetryHistory();
    
    # Deve permitir nova tentativa
    my $new_retry = $fallback->shouldRetry('api_error', $context);
    is($new_retry, 1, 'Should allow retry after clearing history');
};

# Teste 11: Respostas personalizadas
subtest "Custom fallback responses" => sub {
    my $fallback = AIChat::FallbackManager->new();
    
    # Adiciona resposta personalizada
    my $custom_responses = ['resposta personalizada 1', 'resposta personalizada 2'];
    my $added = $fallback->addCustomFallbackResponse('custom', $custom_responses);
    is($added, 1, 'Should add custom responses successfully');
    
    # Verifica se foi adicionada
    my $available_types = $fallback->getAvailableResponseTypes();
    ok(grep { $_ eq 'custom' } @$available_types, 'Custom type should be available');
    
    # Obtém respostas personalizadas
    my $responses = $fallback->getResponsesForType('custom');
    is_deeply($responses, $custom_responses, 'Should return custom responses');
    
    # Remove resposta personalizada
    my $removed = $fallback->removeCustomFallbackResponse('custom');
    is($removed, 1, 'Should remove custom responses successfully');
    
    # Verifica se foi removida
    $available_types = $fallback->getAvailableResponseTypes();
    ok(!grep { $_ eq 'custom' } @$available_types, 'Custom type should not be available');
};

# Teste 12: Tipos de resposta disponíveis
subtest "Available response types" => sub {
    my $fallback = AIChat::FallbackManager->new();
    
    my $types = $fallback->getAvailableResponseTypes();
    
    # Verifica se todos os tipos padrão estão presentes
    ok(grep { $_ eq 'greeting' } @$types, 'Greeting type should be available');
    ok(grep { $_ eq 'help' } @$types, 'Help type should be available');
    ok(grep { $_ eq 'busy' } @$types, 'Busy type should be available');
    ok(grep { $_ eq 'unknown' } @$types, 'Unknown type should be available');
    ok(grep { $_ eq 'error' } @$types, 'Error type should be available');
};

# Executa os testes
done_testing();
