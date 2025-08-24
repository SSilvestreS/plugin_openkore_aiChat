#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 25;
use Test::MockTime qw(set_fixed_time restore_time);

# Adiciona o diretório lib ao @INC
use lib 'AIChat';

# Mock do módulo Log para evitar dependências externas
BEGIN {
    package Log;
    sub debug { 1 }
    sub warning { 1 }
    $INC{'Log.pm'} = 1;
}

use AIChat::Cache;

# Teste 1: Criação de instância
subtest "Cache instance creation" => sub {
    my $cache = AIChat::Cache->new();
    isa_ok($cache, 'AIChat::Cache');
    is($cache->{hits}, 0, 'Initial hits should be 0');
    is($cache->{misses}, 0, 'Initial misses should be 0');
    is($cache->{size}, 0, 'Initial size should be 0');
};

# Teste 2: Geração de chaves de cache
subtest "Cache key generation" => sub {
    my $cache = AIChat::Cache->new();
    
    # Testa geração de chave com mensagem simples
    my $key1 = $cache->_generateCacheKey("oi", {});
    my $key2 = $cache->_generateCacheKey("oi", {});
    is($key1, $key2, 'Same message should generate same key');
    
    # Testa geração de chave com contexto
    my $context1 = { map_name => 'prontera', base_level => 10, job => 'swordman' };
    my $context2 = { map_name => 'prontera', base_level => 10, job => 'swordman' };
    my $key3 = $cache->_generateCacheKey("oi", $context1);
    my $key4 = $cache->_generateCacheKey("oi", $context2);
    is($key3, $key4, 'Same context should generate same key');
    
    # Testa chaves diferentes para contextos diferentes
    my $context3 = { map_name => 'morocc', base_level => 10, job => 'swordman' };
    my $key5 = $cache->_generateCacheKey("oi", $context3);
    isnt($key3, $key5, 'Different context should generate different key');
};

# Teste 3: Operações básicas de cache
subtest "Basic cache operations" => sub {
    my $cache = AIChat::Cache->new();
    my $context = { map_name => 'prontera', base_level => 10 };
    
    # Testa set e get
    $cache->set("oi", $context, "oi ae", 60);
    is($cache->{size}, 1, 'Cache size should be 1 after set');
    
    my $response = $cache->get("oi", $context);
    is($response, "oi ae", 'Should retrieve cached response');
    is($cache->{hits}, 1, 'Cache hits should be 1');
    is($cache->{misses}, 0, 'Cache misses should be 0');
    
    # Testa get com mensagem não existente
    my $missing_response = $cache->get("tchau", $context);
    is($missing_response, undef, 'Should return undef for missing key');
    is($cache->{misses}, 1, 'Cache misses should be 1');
};

# Teste 4: Expiração de cache
subtest "Cache expiration" => sub {
    my $cache = AIChat::Cache->new();
    my $context = { map_name => 'prontera' };
    
    # Define tempo fixo para teste
    set_fixed_time(1000);
    
    # Adiciona item com TTL baixo
    $cache->set("oi", $context, "oi ae", 5);
    is($cache->{size}, 1, 'Cache should have 1 item');
    
    # Avança o tempo para expirar o item
    set_fixed_time(1010);
    
    # Tenta recuperar item expirado
    my $response = $cache->get("oi", $context);
    is($response, undef, 'Should return undef for expired item');
    is($cache->{size}, 0, 'Cache size should be 0 after expiration');
    
    restore_time();
};

# Teste 5: Limpeza automática
subtest "Automatic cache cleanup" => sub {
    my $cache = AIChat::Cache->new();
    my $context = { map_name => 'prontera' };
    
    set_fixed_time(1000);
    
    # Adiciona vários itens
    for my $i (1..5) {
        $cache->set("msg$i", $context, "response$i", 5);
    }
    
    is($cache->{size}, 5, 'Cache should have 5 items');
    
    # Avança o tempo para expirar todos os itens
    set_fixed_time(1010);
    
    # Força limpeza
    $cache->_cleanupIfNeeded();
    
    is($cache->{size}, 0, 'Cache should be empty after cleanup');
    
    restore_time();
};

# Teste 6: Evicção de itens antigos
subtest "Cache eviction" => sub {
    my $cache = AIChat::Cache->new();
    my $context = { map_name => 'prontera' };
    
    # Adiciona itens até atingir o limite
    for my $i (1..1001) {
        $cache->set("msg$i", $context, "response$i", 3600);
    }
    
    # Verifica se a evicção foi feita
    ok($cache->{size} <= 1000, 'Cache size should not exceed max size');
    
    # Verifica se itens mais antigos foram removidos
    my $response = $cache->get("msg1", $context);
    is($response, undef, 'Oldest item should have been evicted');
};

# Teste 7: Busca por similaridade
subtest "Similarity search" => sub {
    my $cache = AIChat::Cache->new();
    my $context = { map_name => 'prontera' };
    
    # Adiciona algumas mensagens
    $cache->set("oi tudo bem", $context, "oi ae", 3600);
    $cache->set("como vai", $context, "tudo bem", 3600);
    
    # Testa busca por similaridade
    my $similar_response = $cache->getSimilar("oi ae", $context, 0.5);
    ok(defined $similar_response, 'Should find similar response');
    
    # Testa com threshold muito alto
    my $no_similar = $cache->getSimilar("oi ae", $context, 0.9);
    is($no_similar, undef, 'Should not find response with high threshold');
};

# Teste 8: Estatísticas do cache
subtest "Cache statistics" => sub {
    my $cache = AIChat::Cache->new();
    my $context = { map_name => 'prontera' };
    
    # Adiciona alguns itens
    $cache->set("oi", $context, "oi ae", 3600);
    $cache->get("oi", $context);
    $cache->get("tchau", $context);
    
    my $stats = $cache->getStats();
    
    is($stats->{size}, 1, 'Stats should show correct size');
    is($stats->{hits}, 1, 'Stats should show correct hits');
    is($stats->{misses}, 1, 'Stats should show correct misses');
    like($stats->{hit_rate}, qr/^\d+\.\d+%$/, 'Hit rate should be formatted correctly');
    is($stats->{max_size}, 1000, 'Max size should be correct');
};

# Teste 9: Limpeza de cache
subtest "Cache clearing" => sub {
    my $cache = AIChat::Cache->new();
    my $context = { map_name => 'prontera' };
    
    # Adiciona alguns itens
    $cache->set("oi", $context, "oi ae", 3600);
    $cache->set("tchau", $context, "tchau", 3600);
    
    is($cache->{size}, 2, 'Cache should have 2 items');
    
    # Limpa o cache
    $cache->clear();
    
    is($cache->{size}, 0, 'Cache should be empty after clear');
    is($cache->{hits}, 0, 'Hits should be reset after clear');
    is($cache->{misses}, 0, 'Misses should be reset after clear');
};

# Teste 10: Remoção de item específico
subtest "Specific item removal" => sub {
    my $cache = AIChat::Cache->new();
    my $context = { map_name => 'prontera' };
    
    # Adiciona itens
    $cache->set("oi", $context, "oi ae", 3600);
    $cache->set("tchau", $context, "tchau", 3600);
    
    is($cache->{size}, 2, 'Cache should have 2 items');
    
    # Remove item específico
    my $removed = $cache->remove("oi", $context);
    is($removed, 1, 'Should return 1 for successful removal');
    is($cache->{size}, 1, 'Cache size should be 1 after removal');
    
    # Tenta remover item inexistente
    my $not_removed = $cache->remove("oi", $context);
    is($not_removed, 0, 'Should return 0 for non-existent item');
};

# Executa os testes
done_testing();
