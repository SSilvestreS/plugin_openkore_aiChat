#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 18;
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

use AIChat::ContextManager;

# Teste 1: Criação de instância
subtest "ContextManager instance creation" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    isa_ok($context_mgr, 'AIChat::ContextManager');
    is($context_mgr->{last_context_update}, 0, 'Initial last context update should be 0');
};

# Teste 2: Atualização de contexto
subtest "Context updating" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    my $character_data = {
        map_name => 'prontera',
        base_level => 15,
        job_level => 10,
        job => 'swordman',
        hp_percent => 100,
        sp_percent => 100,
        exp_percent => 25
    };
    
    set_fixed_time(1000);
    
    # Atualiza contexto
    $context_mgr->updateContext($character_data);
    
    # Verifica se foi atualizado
    my $context = $context_mgr->getCurrentContext();
    is($context->{map_name}, 'prontera', 'Map name should be updated');
    is($context->{base_level}, 15, 'Base level should be updated');
    is($context->{job}, 'swordman', 'Job should be updated');
    is($context->{hp_percent}, 100, 'HP percent should be updated');
    
    restore_time();
};

# Teste 3: Detecção automática de contexto
subtest "Automatic context detection" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    
    # Contexto de combate (HP baixo)
    my $combat_data = {
        map_name => 'gef_fild01',
        base_level => 20,
        job_level => 15,
        job => 'swordman',
        hp_percent => 30,
        sp_percent => 50,
        exp_percent => 0
    };
    
    $context_mgr->updateContext($combat_data);
    my $context = $context_mgr->getCurrentContext();
    is($context->{type}, 'combat', 'Should detect combat context with low HP');
    
    # Contexto de leveling
    my $leveling_data = {
        map_name => 'gef_fild01',
        base_level => 20,
        job_level => 15,
        job => 'swordman',
        hp_percent => 100,
        sp_percent => 100,
        exp_percent => 75
    };
    
    $context_mgr->updateContext($leveling_data);
    $context = $context_mgr->getCurrentContext();
    is($context->{type}, 'leveling', 'Should detect leveling context with high exp');
    
    # Contexto de trading
    my $trading_data = {
        map_name => 'prontera',
        base_level => 20,
        job_level => 15,
        job => 'merchant',
        hp_percent => 100,
        sp_percent => 100,
        exp_percent => 0
    };
    
    $context_mgr->updateContext($trading_data);
    $context = $context_mgr->getCurrentContext();
    is($context->{type}, 'trading', 'Should detect trading context in city');
};

# Teste 4: Mudança de contexto
subtest "Context changing" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    
    # Inicia com contexto geral
    my $context = $context_mgr->getCurrentContext();
    is($context->{type}, 'general', 'Should start with general context');
    
    # Muda para contexto de combate
    my $combat_data = {
        map_name => 'gef_fild01',
        base_level => 20,
        job_level => 15,
        job => 'swordman',
        hp_percent => 25,
        sp_percent => 30,
        exp_percent => 0
    };
    
    $context_mgr->updateContext($combat_data);
    $context = $context_mgr->getCurrentContext();
    is($context->{type}, 'combat', 'Should change to combat context');
    is($context->{state}, 'danger', 'Should be in danger state with low HP');
    
    # Verifica se dados específicos foram inicializados
    ok(exists $context->{context_data}->{combat_start_time}, 'Combat start time should be set');
    ok(exists $context->{context_data}->{monsters_killed}, 'Monsters killed counter should be set');
};

# Teste 5: Atualização de estado
subtest "State updating" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    
    # Estado de perigo
    my $danger_data = {
        map_name => 'gef_fild01',
        base_level => 20,
        job_level => 15,
        job => 'swordman',
        hp_percent => 20,
        sp_percent => 10,
        exp_percent => 0
    };
    
    $context_mgr->updateContext($danger_data);
    my $context = $context_mgr->getCurrentContext();
    is($context->{state}, 'danger', 'Should be in danger state with very low HP');
    
    # Estado ocupado
    my $busy_data = {
        map_name => 'gef_fild01',
        base_level => 20,
        job_level => 15,
        job => 'swordman',
        hp_percent => 60,
        sp_percent => 70,
        exp_percent => 0
    };
    
    $context_mgr->updateContext($busy_data);
    $context = $context_mgr->getCurrentContext();
    is($context->{state}, 'busy', 'Should be in busy state with moderate HP');
    
    # Estado ativo
    my $active_data = {
        map_name => 'gef_fild01',
        base_level => 20,
        job_level => 15,
        job => 'swordman',
        hp_percent => 90,
        sp_percent => 90,
        exp_percent => 50
    };
    
    $context_mgr->updateContext($active_data);
    $context = $context_mgr->getCurrentContext();
    is($context->{state}, 'active', 'Should be in active state with high HP and exp');
};

# Teste 6: Contexto para mensagem específica
subtest "Context for specific message" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    my $character_data = {
        map_name => 'prontera',
        base_level => 20,
        job_level => 15,
        job => 'swordman',
        hp_percent => 100,
        sp_percent => 100,
        exp_percent => 0
    };
    
    $context_mgr->updateContext($character_data);
    
    # Obtém contexto para mensagem
    my $message_context = $context_mgr->getContextForMessage("oi", "Player1");
    
    is($message_context->{message_context}->{sender}, 'Player1', 'Sender should be set');
    is($message_context->{message_context}->{message_type}, 'greeting', 'Message type should be greeting');
    is($message_context->{message_context}->{urgency}, 1, 'Urgency should be 1 for greeting');
    
    # Testa mensagem urgente
    my $urgent_context = $context_mgr->getContextForMessage("ajuda socorro", "Player2");
    is($urgent_context->{message_context}->{message_type}, 'urgent', 'Message type should be urgent');
    is($urgent_context->{message_context}->{urgency}, 1, 'Urgency should be 1 for general context');
};

# Teste 7: Classificação de mensagens
subtest "Message classification" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    
    # Testa diferentes tipos de mensagem
    my $greeting_type = $context_mgr->_classifyMessage("oi");
    is($greeting_type, 'greeting', 'Should classify "oi" as greeting');
    
    my $urgent_type = $context_mgr->_classifyMessage("ajuda socorro");
    is($urgent_type, 'urgent', 'Should classify urgent message correctly');
    
    my $trading_type = $context_mgr->_classifyMessage("preco do item");
    is($trading_type, 'trading', 'Should classify trading message correctly');
    
    my $quest_type = $context_mgr->_classifyMessage("quest objetivo");
    is($quest_type, 'quest', 'Should classify quest message correctly');
    
    my $leveling_type = $context_mgr->_classifyMessage("onde upar level");
    is($leveling_type, 'leveling', 'Should classify leveling message correctly');
    
    my $general_type = $context_mgr->_classifyMessage("mensagem estranha");
    is($general_type, 'general', 'Should classify unknown message as general');
};

# Teste 8: Cálculo de urgência
subtest "Urgency calculation" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    
    # Contexto de perigo
    my $danger_context = {
        state => 'danger',
        type => 'combat'
    };
    
    my $danger_urgency = $context_mgr->_calculateUrgency("oi", $danger_context);
    is($danger_urgency, 3, 'Urgency should be 3 in danger state');
    
    # Contexto ocupado
    my $busy_context = {
        state => 'busy',
        type => 'leveling'
    };
    
    my $busy_urgency = $context_mgr->_calculateUrgency("oi", $busy_context);
    is($busy_urgency, 2, 'Urgency should be 2 in busy state');
    
    # Mensagem urgente em contexto normal
    my $normal_context = {
        state => 'idle',
        type => 'general'
    };
    
    my $urgent_message_urgency = $context_mgr->_calculateUrgency("ajuda socorro", $normal_context);
    is($urgent_message_urgency, 4, 'Urgency should be 4 for urgent message');
};

# Teste 9: Histórico de contexto
subtest "Context history" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    
    # Atualiza contexto várias vezes
    for my $i (1..5) {
        my $data = {
            map_name => "map$i",
            base_level => 10 + $i,
            job_level => 5 + $i,
            job => 'swordman',
            hp_percent => 100,
            sp_percent => 100,
            exp_percent => 0
        };
        $context_mgr->updateContext($data);
    }
    
    # Obtém histórico
    my @history = $context_mgr->getContextHistory(3);
    is(scalar @history, 3, 'Should return 3 most recent contexts');
    
    # Verifica se o mais recente está por último
    my $latest = $history[-1];
    is($latest->{map_name}, 'map5', 'Latest context should be map5');
    is($latest->{base_level}, 15, 'Latest context should have base level 15');
};

# Teste 10: Adição de eventos
subtest "Event addition" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    
    # Adiciona alguns eventos
    $context_mgr->addEvent('monster_killed', { monster => 'poring', exp => 100 });
    $context_mgr->addEvent('item_dropped', { item => 'red_potion', amount => 1 });
    
    # Obtém eventos
    my @events = $context_mgr->getEvents();
    is(scalar @events, 2, 'Should have 2 events');
    
    # Obtém eventos específicos
    my @monster_events = $context_mgr->getEvents('monster_killed');
    is(scalar @monster_events, 1, 'Should have 1 monster killed event');
    is($monster_events[0]->{data}->{monster}, 'poring', 'Event data should be correct');
};

# Teste 11: Estatísticas de contexto
subtest "Context statistics" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    
    # Atualiza contexto algumas vezes
    for my $i (1..3) {
        my $data = {
            map_name => "map$i",
            base_level => 10 + $i,
            job_level => 5 + $i,
            job => 'swordman',
            hp_percent => 100,
            sp_percent => 100,
            exp_percent => 0
        };
        $context_mgr->updateContext($data);
    }
    
    my $stats = $context_mgr->getContextStats();
    
    is($stats->{total_contexts}, 3, 'Should have 3 total contexts');
    ok($stats->{context_changes} >= 0, 'Context changes should be non-negative');
    is($stats->{current_context}, 'general', 'Current context should be general');
};

# Teste 12: Configuração de contexto
subtest "Context configuration" => sub {
    my $context_mgr = AIChat::ContextManager->new();
    
    # Define configuração
    my $set_result = $context_mgr->setContextConfig('max_history', 25);
    is($set_result, 1, 'Should set config successfully');
    
    # Obtém configuração
    my $max_history = $context_mgr->getContextConfig('max_history');
    is($max_history, 25, 'Should get updated config value');
    
    # Tenta definir configuração inválida
    my $invalid_result = $context_mgr->setContextConfig('invalid_key', 'value');
    is($invalid_result, 0, 'Should not set invalid config key');
};

# Executa os testes
done_testing();
