package AIChat::Cache;

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use Time::HiRes qw(time);
use Log qw(debug warning);

# Cache em memória simples (pode ser expandido para Redis/arquivo)
my %cache = ();
my %cache_metadata = ();

# Configurações do cache
use constant {
    DEFAULT_TTL => 3600,        # 1 hora em segundos
    MAX_CACHE_SIZE => 1000,     # Máximo de itens no cache
    CLEANUP_INTERVAL => 300,    # Limpeza a cada 5 minutos
    SIMILARITY_THRESHOLD => 0.8 # Threshold para similaridade
};

# Contador para limpeza automática
my $last_cleanup = time();

sub new {
    my $class = shift;
    my $self = {
        hits => 0,
        misses => 0,
        size => 0
    };
    bless $self, $class;
    return $self;
}

# Gera chave única para o cache
sub _generateCacheKey {
    my ($message, $context) = @_;
    
    # Normaliza a mensagem (remove espaços extras, converte para minúsculas)
    my $normalized_message = lc($message);
    $normalized_message =~ s/\s+/ /g;
    $normalized_message =~ s/^\s+|\s+$//g;
    
    # Cria contexto string com informações relevantes
    my $context_str = '';
    if ($context && ref($context) eq 'HASH') {
        $context_str = join('|', 
            $context->{map_name} || '',
            $context->{base_level} || 0,
            $context->{job} || '',
            $context->{context_type} || 'general'
        );
    }
    
    # Combina mensagem normalizada com contexto
    return md5_hex($normalized_message . '|' . $context_str);
}

# Obtém resposta do cache
sub get {
    my ($self, $message, $context) = @_;
    
    my $cache_key = _generateCacheKey($message, $context);
    
    # Verifica se existe no cache e não expirou
    if (exists $cache{$cache_key} && exists $cache_metadata{$cache_key}) {
        my $metadata = $cache_metadata{$cache_key};
        
        if (time() < $metadata->{expires_at}) {
            $self->{hits}++;
            debug "[aiChat::Cache] Cache hit for key: $cache_key\n", "plugin";
            return $cache{$cache_key};
        } else {
            # Remove item expirado
            delete $cache{$cache_key};
            delete $cache_metadata{$cache_key};
            $self->{size}--;
        }
    }
    
    $self->{misses}++;
    debug "[aiChat::Cache] Cache miss for key: $cache_key\n", "plugin";
    return undef;
}

# Armazena resposta no cache
sub set {
    my ($self, $message, $context, $response, $ttl) = @_;
    
    my $cache_key = _generateCacheKey($message, $context);
    my $expires_at = time() + ($ttl || DEFAULT_TTL);
    
    # Verifica se precisa limpar o cache
    $self->_cleanupIfNeeded();
    
    # Verifica se há espaço no cache
    if ($self->{size} >= MAX_CACHE_SIZE) {
        $self->_evictOldest();
    }
    
    # Armazena no cache
    $cache{$cache_key} = $response;
    $cache_metadata{$cache_key} = {
        created_at => time(),
        expires_at => $expires_at,
        access_count => 1,
        last_accessed => time()
    };
    
    $self->{size}++;
    debug "[aiChat::Cache] Cached response for key: $cache_key (TTL: $ttl seconds)\n", "plugin";
}

# Busca por similaridade (respostas similares)
sub getSimilar {
    my ($self, $message, $context, $threshold) = @_;
    
    $threshold ||= SIMILARITY_THRESHOLD;
    my $target_key = _generateCacheKey($message, $context);
    
    foreach my $cache_key (keys %cache) {
        next unless exists $cache_metadata{$cache_key};
        
        my $metadata = $cache_metadata{$cache_key};
        next if time() >= $metadata->{expires_at};
        
        # Calcula similaridade simples baseada em palavras-chave
        my $similarity = $self->_calculateSimilarity($message, $cache_key);
        
        if ($similarity >= $threshold) {
            # Atualiza contadores de acesso
            $metadata->{access_count}++;
            $metadata->{last_accessed} = time();
            
            debug "[aiChat::Cache] Found similar response (similarity: $similarity)\n", "plugin";
            return $cache{$cache_key};
        }
    }
    
    return undef;
}

# Calcula similaridade entre duas mensagens
sub _calculateSimilarity {
    my ($self, $message1, $cache_key) = @_;
    
    # Implementação simples de similaridade baseada em palavras-chave
    # Pode ser expandida para usar embeddings ou algoritmos mais sofisticados
    
    my @words1 = split(/\s+/, lc($message1));
    my @words2 = split(/\s+/, lc($cache_key));
    
    my $common_words = 0;
    my $total_words = @words1 + @words2;
    
    foreach my $word1 (@words1) {
        foreach my $word2 (@words2) {
            if ($word1 eq $word2 && length($word1) > 2) {
                $common_words++;
            }
        }
    }
    
    return $total_words > 0 ? ($common_words * 2) / $total_words : 0;
}

# Limpeza automática do cache
sub _cleanupIfNeeded {
    my ($self) = @_;
    
    my $now = time();
    return if ($now - $last_cleanup) < CLEANUP_INTERVAL;
    
    $last_cleanup = $now;
    my $removed = 0;
    
    foreach my $cache_key (keys %cache) {
        if (exists $cache_metadata{$cache_key}) {
            my $metadata = $cache_metadata{$cache_key};
            
            if ($now >= $metadata->{expires_at}) {
                delete $cache{$cache_key};
                delete $cache_metadata{$cache_key};
                $removed++;
            }
        }
    }
    
    $self->{size} -= $removed;
    debug "[aiChat::Cache] Cleanup removed $removed expired items\n", "plugin";
}

# Remove itens mais antigos quando o cache está cheio
sub _evictOldest {
    my ($self) = @_;
    
    my @sorted_keys = sort {
        $cache_metadata{$a}->{last_accessed} <=> $cache_metadata{$b}->{last_accessed}
    } keys %cache;
    
    # Remove 10% dos itens mais antigos
    my $remove_count = int($self->{size} * 0.1) + 1;
    
    for (my $i = 0; $i < $remove_count && $i < @sorted_keys; $i++) {
        my $key = $sorted_keys[$i];
        delete $cache{$key};
        delete $cache_metadata{$key};
    }
    
    $self->{size} -= $remove_count;
    debug "[aiChat::Cache] Evicted $remove_count oldest items\n", "plugin";
}

# Estatísticas do cache
sub getStats {
    my ($self) = @_;
    
    return {
        size => $self->{size},
        hits => $self->{hits},
        misses => $self->{misses},
        hit_rate => $self->{hits} + $self->{misses} > 0 ? 
                   sprintf("%.2f%%", ($self->{hits} / ($self->{hits} + $self->{misses})) * 100) : "0%",
        max_size => MAX_CACHE_SIZE,
        cleanup_interval => CLEANUP_INTERVAL
    };
}

# Limpa todo o cache
sub clear {
    my ($self) = @_;
    
    %cache = ();
    %cache_metadata = {};
    $self->{size} = 0;
    $self->{hits} = 0;
    $self->{misses} = 0;
    
    debug "[aiChat::Cache] Cache cleared\n", "plugin";
}

# Remove item específico do cache
sub remove {
    my ($self, $message, $context) = @_;
    
    my $cache_key = _generateCacheKey($message, $context);
    
    if (exists $cache{$cache_key}) {
        delete $cache{$cache_key};
        delete $cache_metadata{$cache_key};
        $self->{size}--;
        debug "[aiChat::Cache] Removed item: $cache_key\n", "plugin";
        return 1;
    }
    
    return 0;
}

1;
