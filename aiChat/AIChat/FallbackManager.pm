package AIChat::FallbackManager;

use strict;
use warnings;
use Log qw(warning message debug error);
use Time::HiRes qw(time);

# Configurações de fallback
use constant {
    MAX_RETRIES => 3,
    RETRY_DELAY_BASE => 1,      # Delay base em segundos
    RETRY_DELAY_MULTIPLIER => 2, # Multiplicador exponencial
    MAX_RETRY_DELAY => 30,       # Delay máximo em segundos
    FALLBACK_RESPONSES_TTL => 86400, # 24 horas para respostas de fallback
};

# Respostas de fallback pré-definidas
my %fallback_responses = (
    'greeting' => [
        "oi",
        "ae",
        "fala",
        "e ai",
        "oi tudo bem"
    ],
    'help' => [
        "precisa de ajuda?",
        "o que vc quer saber?",
        "como posso ajudar?",
        "fala ai o que precisa"
    ],
    'busy' => [
        "to upando agora",
        "to ocupado",
        "depois falo",
        "to em quest"
    ],
    'unknown' => [
        "n entendi",
        "o que?",
        "fala direito",
        "n sei o que vc quer"
    ],
    'error' => [
        "deu erro aqui",
        "to com problema",
        "n consigo responder agora",
        "tenta de novo"
    ]
);

# Histórico de tentativas de retry
my %retry_history = ();

# Contadores de fallback
my %fallback_stats = (
    total_fallbacks => 0,
    retry_successes => 0,
    retry_failures => 0,
    fallback_responses_used => 0
);

sub new {
    my $class = shift;
    my $self = {
        retry_count => 0,
        last_retry_time => 0
    };
    bless $self, $class;
    return $self;
}

# Tenta fazer retry com backoff exponencial
sub shouldRetry {
    my ($self, $error_type, $context) = @_;
    
    my $retry_key = $self->_getRetryKey($error_type, $context);
    
    # Verifica se já tentou demais
    if (!exists $retry_history{$retry_key}) {
        $retry_history{$retry_key} = {
            count => 0,
            first_attempt => time(),
            last_attempt => 0
        };
    }
    
    my $retry_info = $retry_history{$retry_key};
    
    # Verifica se não excedeu o número máximo de tentativas
    if ($retry_info->{count} >= MAX_RETRIES) {
        debug "[aiChat::Fallback] Max retries exceeded for $retry_key\n", "plugin";
        return 0;
    }
    
    # Calcula delay exponencial
    my $delay = RETRY_DELAY_BASE * (RETRY_DELAY_MULTIPLIER ** $retry_info->{count});
    $delay = $delay > MAX_RETRY_DELAY ? MAX_RETRY_DELAY : $delay;
    
    # Verifica se já passou tempo suficiente desde a última tentativa
    my $time_since_last = time() - $retry_info->{last_attempt};
    
    if ($time_since_last >= $delay) {
        $retry_info->{count}++;
        $retry_info->{last_attempt} = time();
        debug "[aiChat::Fallback] Retry attempt $retry_info->{count} for $retry_key\n", "plugin";
        return 1;
    }
    
    return 0;
}

# Gera chave única para retry
sub _getRetryKey {
    my ($self, $error_type, $context) = @_;
    
    my $context_str = '';
    if ($context && ref($context) eq 'HASH') {
        $context_str = join('|', 
            $context->{map_name} || '',
            $context->{base_level} || 0,
            $context->{job} || ''
        );
    }
    
    return $error_type . '|' . $context_str;
}

# Registra sucesso de retry
sub recordRetrySuccess {
    my ($self, $error_type, $context) = @_;
    
    my $retry_key = $self->_getRetryKey($error_type, $context);
    
    if (exists $retry_history{$retry_key}) {
        delete $retry_history{$retry_key};
        $fallback_stats{retry_successes}++;
        debug "[aiChat::Fallback] Retry successful for $retry_key\n", "plugin";
    }
}

# Registra falha de retry
sub recordRetryFailure {
    my ($self, $error_type, $context) = @_;
    
    $fallback_stats{retry_failures}++;
    debug "[aiChat::Fallback] Retry failed for $error_type\n", "plugin";
}

# Obtém resposta de fallback baseada no contexto
sub getFallbackResponse {
    my ($self, $message, $context) = @_;
    
    $fallback_stats{fallback_responses_used}++;
    
    # Determina o tipo de resposta baseado na mensagem
    my $response_type = $self->_classifyMessage($message);
    
    # Obtém respostas disponíveis para o tipo
    my $responses = $fallback_responses{$response_type} || $fallback_responses{'unknown'};
    
    # Seleciona resposta aleatória
    my $random_index = int(rand(scalar @$responses));
    my $response = $responses->[$random_index];
    
    # Adiciona contexto específico se disponível
    $response = $self->_addContextToResponse($response, $context);
    
    debug "[aiChat::Fallback] Using fallback response: $response\n", "plugin";
    return $response;
}

# Classifica a mensagem para determinar o tipo de resposta
sub _classifyMessage {
    my ($self, $message) = @_;
    
    my $lower_message = lc($message);
    
    # Saudações
    if ($lower_message =~ /^(oi|ae|fala|e ai|hello|hi|ola|hey)/) {
        return 'greeting';
    }
    
    # Pedidos de ajuda
    if ($lower_message =~ /(ajuda|help|como|o que|que|quem|onde|quando)/) {
        return 'help';
    }
    
    # Mensagens de ocupado
    if ($lower_message =~ /(ocupado|upando|quest|batalha|combate)/) {
        return 'busy';
    }
    
    # Erros ou problemas
    if ($lower_message =~ /(erro|problema|bug|falha|n funciona)/) {
        return 'error';
    }
    
    return 'unknown';
}

# Adiciona contexto específico à resposta
sub _addContextToResponse {
    my ($self, $response, $context) = @_;
    
    return $response unless $context && ref($context) eq 'HASH';
    
    # Adiciona informações do mapa se relevante
    if ($context->{map_name} && $context->{map_name} ne 'Desconhecido') {
        if ($response =~ /oi/) {
            $response .= " to no mapa $context->{map_name}";
        }
    }
    
    # Adiciona informações de level se relevante
    if ($context->{base_level} && $context->{base_level} > 0) {
        if ($response =~ /upando/) {
            $response .= " level $context->{base_level}";
        }
    }
    
    return $response;
}

# Obtém estatísticas de fallback
sub getStats {
    my ($self) = @_;
    
    return {
        %fallback_stats,
        retry_history_size => scalar keys %retry_history,
        max_retries => MAX_RETRIES,
        retry_delay_base => RETRY_DELAY_BASE,
        retry_delay_multiplier => RETRY_DELAY_MULTIPLIER,
        max_retry_delay => MAX_RETRY_DELAY
    };
}

# Limpa histórico de retry
sub clearRetryHistory {
    my ($self) = @_;
    
    %retry_history = ();
    debug "[aiChat::Fallback] Retry history cleared\n", "plugin";
}

# Adiciona resposta de fallback personalizada
sub addCustomFallbackResponse {
    my ($self, $type, $responses) = @_;
    
    if (ref($responses) eq 'ARRAY' && @$responses > 0) {
        $fallback_responses{$type} = $responses;
        debug "[aiChat::Fallback] Added custom fallback responses for type: $type\n", "plugin";
        return 1;
    }
    
    warning "[aiChat::Fallback] Invalid responses format for type: $type\n", "plugin";
    return 0;
}

# Remove resposta de fallback personalizada
sub removeCustomFallbackResponse {
    my ($self, $type) = @_;
    
    if (exists $fallback_responses{$type} && $type ne 'unknown') {
        delete $fallback_responses{$type};
        debug "[aiChat::Fallback] Removed custom fallback responses for type: $type\n", "plugin";
        return 1;
    }
    
    return 0;
}

# Obtém tipos de resposta disponíveis
sub getAvailableResponseTypes {
    my ($self) = @_;
    
    return keys %fallback_responses;
}

# Obtém respostas para um tipo específico
sub getResponsesForType {
    my ($self, $type) = @_;
    
    return $fallback_responses{$type} || [];
}

1;
