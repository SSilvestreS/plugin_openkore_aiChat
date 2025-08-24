package AIChat::ContextManager;

use strict;
use warnings;
use Log qw(warning message debug error);
use Time::HiRes qw(time);

# Tipos de contexto
use constant {
    CONTEXT_COMBAT => 'combat',
    CONTEXT_LEVELING => 'leveling',
    CONTEXT_TRADING => 'trading',
    CONTEXT_QUEST => 'quest',
    CONTEXT_SOCIAL => 'social',
    CONTEXT_EXPLORATION => 'exploration',
    CONTEXT_GENERAL => 'general'
};

# Estados de contexto
use constant {
    STATE_IDLE => 'idle',
    STATE_ACTIVE => 'active',
    STATE_BUSY => 'busy',
    STATE_DANGER => 'danger'
};

# Contexto atual do bot
my %current_context = (
    type => CONTEXT_GENERAL,
    state => STATE_IDLE,
    map_name => '',
    base_level => 0,
    job_level => 0,
    job => '',
    hp_percent => 100,
    sp_percent => 100,
    exp_percent => 0,
    last_update => 0,
    context_data => {}
);

# Histórico de contextos
my @context_history = ();

# Configurações de contexto
my %context_config = (
    max_history => 50,
    context_ttl => 300,  # 5 minutos
    update_interval => 10 # 10 segundos
);

# Padrões de contexto para detecção automática
my %context_patterns = (
    CONTEXT_COMBAT => {
        keywords => ['batalha', 'combate', 'monstro', 'mob', 'ataque', 'defesa', 'hp', 'sp'],
        maps => ['gef_fild01', 'gef_fild02', 'moc_fild01', 'moc_fild02'],
        conditions => sub {
            my ($context) = @_;
            return $context->{hp_percent} < 80 || $context->{state} eq STATE_DANGER;
        }
    },
    CONTEXT_LEVELING => {
        keywords => ['upar', 'level', 'exp', 'experiencia', 'grind'],
        maps => ['gef_fild01', 'gef_fild02', 'moc_fild01', 'moc_fild02'],
        conditions => sub {
            my ($context) = @_;
            return $context->{exp_percent} > 0 && $context->{state} eq STATE_ACTIVE;
        }
    },
    CONTEXT_TRADING => {
        keywords => ['vender', 'comprar', 'preco', 'mercado', 'shop', 'venda'],
        maps => ['prontera', 'morocc', 'geffen', 'alberta'],
        conditions => sub {
            my ($context) = @_;
            return $context->{state} eq STATE_IDLE && $context->{map_name} =~ /(prontera|morocc|geffen|alberta)/;
        }
    },
    CONTEXT_QUEST => {
        keywords => ['quest', 'missao', 'objetivo', 'npc', 'dialogo'],
        maps => ['prontera', 'geffen', 'morocc', 'payon'],
        conditions => sub {
            my ($context) = @_;
            return $context->{state} eq STATE_ACTIVE && $context->{context_data}->{quest_active};
        }
    }
);

sub new {
    my $class = shift;
    my $self = {
        last_context_update => 0
    };
    bless $self, $class;
    return $self;
}

# Atualiza o contexto atual
sub updateContext {
    my ($self, $character_data) = @_;
    
    my $now = time();
    
    # Verifica se precisa atualizar
    return if ($now - $self->{last_context_update}) < $context_config{update_interval};
    
    $self->{last_context_update} = $now;
    
    # Atualiza dados básicos
    $current_context{map_name} = $character_data->{map_name} || '';
    $current_context{base_level} = $character_data->{base_level} || 0;
    $current_context{job_level} = $character_data->{job_level} || 0;
    $current_context{job} = $character_data->{job} || '';
    $current_context{hp_percent} = $character_data->{hp_percent} || 100;
    $current_context{sp_percent} = $character_data->{sp_percent} || 100;
    $current_context{exp_percent} = $character_data->{exp_percent} || 0;
    $current_context{last_update} = $now;
    
    # Detecta contexto automaticamente
    my $detected_context = $self->_detectContext();
    if ($detected_context ne $current_context{type}) {
        $self->_changeContext($detected_context);
    }
    
    # Atualiza estado baseado no contexto
    $self->_updateState();
    
    # Adiciona ao histórico
    $self->_addToHistory();
    
    debug "[aiChat::Context] Context updated: $current_context{type} ($current_context{state})\n", "plugin";
}

# Detecta o contexto automaticamente
sub _detectContext {
    my ($self) = @_;
    
    foreach my $context_type (keys %context_patterns) {
        my $pattern = $context_patterns{$context_type};
        
        # Verifica condições
        if (exists $pattern->{conditions} && ref($pattern->{conditions}) eq 'CODE') {
            if ($pattern->{conditions}->(\%current_context)) {
                return $context_type;
            }
        }
        
        # Verifica mapa
        if (exists $pattern->{maps}) {
            foreach my $map (@{$pattern->{maps}}) {
                if ($current_context{map_name} =~ /$map/i) {
                    return $context_type;
                }
            }
        }
    }
    
    return CONTEXT_GENERAL;
}

# Muda o contexto
sub _changeContext {
    my ($self, $new_context) = @_;
    
    my $old_context = $current_context{type};
    $current_context{type} = $new_context;
    
    # Limpa dados específicos do contexto anterior
    $current_context{context_data} = {};
    
    # Inicializa dados específicos do novo contexto
    $self->_initializeContextData($new_context);
    
    debug "[aiChat::Context] Context changed from $old_context to $new_context\n", "plugin";
}

# Inicializa dados específicos do contexto
sub _initializeContextData {
    my ($self, $context_type) = @_;
    
    if ($context_type eq CONTEXT_COMBAT) {
        $current_context{context_data} = {
            combat_start_time => time(),
            monsters_killed => 0,
            damage_taken => 0
        };
    } elsif ($context_type eq CONTEXT_LEVELING) {
        $current_context{context_data} = {
            leveling_start_time => time(),
            exp_gained => 0,
            levels_gained => 0
        };
    } elsif ($context_type eq CONTEXT_TRADING) {
        $current_context{context_data} = {
            trading_start_time => time(),
            items_sold => 0,
            zen_earned => 0
        };
    } elsif ($context_type eq CONTEXT_QUEST) {
        $current_context{context_data} = {
            quest_active => 1,
            quest_start_time => time(),
            quest_objectives => []
        };
    }
}

# Atualiza o estado baseado no contexto
sub _updateState {
    my ($self) = @_;
    
    my $new_state = STATE_IDLE;
    
    if ($current_context{type} eq CONTEXT_COMBAT) {
        if ($current_context{hp_percent} < 30) {
            $new_state = STATE_DANGER;
        } elsif ($current_context{hp_percent} < 70) {
            $new_state = STATE_BUSY;
        } else {
            $new_state = STATE_ACTIVE;
        }
    } elsif ($current_context{type} eq CONTEXT_LEVELING) {
        $new_state = STATE_ACTIVE;
    } elsif ($current_context{type} eq CONTEXT_TRADING) {
        $new_state = STATE_IDLE;
    } elsif ($current_context{type} eq CONTEXT_QUEST) {
        $new_state = STATE_ACTIVE;
    }
    
    if ($new_state ne $current_context{state}) {
        $current_context{state} = $new_state;
        debug "[aiChat::Context] State changed to: $new_state\n", "plugin";
    }
}

# Adiciona contexto ao histórico
sub _addToHistory {
    my ($self) = @_;
    
    my $context_snapshot = {
        timestamp => time(),
        %current_context
    };
    
    push @context_history, $context_snapshot;
    
    # Mantém apenas o histórico máximo
    if (@context_history > $context_config{max_history}) {
        shift @context_history;
    }
}

# Obtém contexto atual
sub getCurrentContext {
    my ($self) = @_;
    
    return { %current_context };
}

# Obtém contexto para uma mensagem específica
sub getContextForMessage {
    my ($self, $message, $sender) = @_;
    
    my $context = $self->getCurrentContext();
    
    # Adiciona informações específicas da mensagem
    $context->{message_context} = {
        sender => $sender,
        message_time => time(),
        message_type => $self->_classifyMessage($message),
        urgency => $self->_calculateUrgency($message, $context)
    };
    
    return $context;
}

# Classifica o tipo de mensagem
sub _classifyMessage {
    my ($self, $message) = @_;
    
    my $lower_message = lc($message);
    
    if ($lower_message =~ /(ajuda|help|socorro|emergencia)/) {
        return 'urgent';
    } elsif ($lower_message =~ /(oi|ae|fala)/) {
        return 'greeting';
    } elsif ($lower_message =~ /(preco|vender|comprar)/) {
        return 'trading';
    } elsif ($lower_message =~ /(quest|missao|objetivo)/) {
        return 'quest';
    } elsif ($lower_message =~ /(upar|level|exp)/) {
        return 'leveling';
    } else {
        return 'general';
    }
}

# Calcula urgência da mensagem
sub _calculateUrgency {
    my ($self, $message, $context) = @_;
    
    my $urgency = 1; # Baixa urgência por padrão
    
    # Aumenta urgência baseado no contexto
    if ($context->{state} eq STATE_DANGER) {
        $urgency += 2;
    } elsif ($context->{state} eq STATE_BUSY) {
        $urgency += 1;
    }
    
    # Aumenta urgência baseado no tipo de mensagem
    my $message_type = $self->_classifyMessage($message);
    if ($message_type eq 'urgent') {
        $urgency += 3;
    } elsif ($message_type eq 'trading') {
        $urgency += 1;
    }
    
    return $urgency;
}

# Obtém contexto histórico
sub getContextHistory {
    my ($self, $limit) = @_;
    
    $limit ||= 10;
    my @recent_contexts = @context_history;
    
    if (@recent_contexts > $limit) {
        @recent_contexts = @context_history[-$limit..-1];
    }
    
    return @recent_contexts;
}

# Obtém contexto por período
sub getContextByPeriod {
    my ($self, $start_time, $end_time) = @_;
    
    my @period_contexts = ();
    
    foreach my $context (@context_history) {
        if ($context->{timestamp} >= $start_time && $context->{timestamp} <= $end_time) {
            push @period_contexts, $context;
        }
    }
    
    return @period_contexts;
}

# Adiciona evento ao contexto atual
sub addEvent {
    my ($self, $event_type, $event_data) = @_;
    
    if (!exists $current_context{context_data}->{events}) {
        $current_context{context_data}->{events} = [];
    }
    
    my $event = {
        type => $event_type,
        data => $event_data,
        timestamp => time()
    };
    
    push @{$current_context{context_data}->{events}}, $event;
    
    debug "[aiChat::Context] Event added: $event_type\n", "plugin";
}

# Obtém eventos do contexto atual
sub getEvents {
    my ($self, $event_type) = @_;
    
    if (!exists $current_context{context_data}->{events}) {
        return ();
    }
    
    if ($event_type) {
        return grep { $_->{type} eq $event_type } @{$current_context{context_data}->{events}};
    }
    
    return @{$current_context{context_data}->{events}};
}

# Obtém estatísticas do contexto
sub getContextStats {
    my ($self) = @_;
    
    my $total_time = time() - $current_context{last_update};
    
    return {
        current_context => $current_context{type},
        current_state => $current_context{state},
        context_duration => $total_time,
        total_contexts => scalar @context_history,
        context_changes => scalar grep { $_->{type} ne $current_context{type} } @context_history
    };
}

# Limpa histórico de contexto
sub clearContextHistory {
    my ($self) = @_;
    
    @context_history = ();
    debug "[aiChat::Context] Context history cleared\n", "plugin";
}

# Define configuração de contexto
sub setContextConfig {
    my ($self, $key, $value) = @_;
    
    if (exists $context_config{$key}) {
        $context_config{$key} = $value;
        debug "[aiChat::Context] Config updated: $key = $value\n", "plugin";
        return 1;
    }
    
    return 0;
}

# Obtém configuração de contexto
sub getContextConfig {
    my ($self, $key) = @_;
    
    return $context_config{$key};
}

1;
