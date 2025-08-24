package AIChat::Logger;

use strict;
use warnings;
use Time::HiRes qw(time gettimeofday);
use File::Path qw(make_path);
use JSON::Tiny qw(encode_json);

# Níveis de log
use constant {
    LOG_DEBUG => 0,
    LOG_INFO => 1,
    LOG_WARN => 2,
    LOG_ERROR => 3,
    LOG_FATAL => 4
};

# Nomes dos níveis
my @LOG_LEVELS = qw(DEBUG INFO WARN ERROR FATAL);

# Configuração do logger
my %logger_config = (
    log_level => LOG_INFO,
    log_to_file => 1,
    log_to_console => 1,
    log_file_path => 'logs',
    log_file_prefix => 'aichat',
    max_file_size => 10 * 1024 * 1024, # 10MB
    max_files => 5,
    log_format => 'json', # json, text, or both
    enable_timestamps => 1,
    enable_context => 1,
    enable_performance => 1
);

# Handles de arquivo
my %log_files = ();

# Estatísticas de logging
my %log_stats = (
    total_logs => 0,
    logs_by_level => {},
    logs_by_context => {},
    performance_metrics => {}
);

# Inicializa estatísticas
foreach my $level (@LOG_LEVELS) {
    $log_stats{logs_by_level}{$level} = 0;
}

sub new {
    my $class = shift;
    my $self = {
        context => {},
        start_time => time()
    };
    bless $self, $class;
    
    # Inicializa o logger
    $self->_initializeLogger();
    
    return $self;
}

# Inicializa o logger
sub _initializeLogger {
    my ($self) = @_;
    
    # Cria diretório de logs se não existir
    if ($logger_config{log_to_file}) {
        make_path($logger_config{log_file_path}) unless -d $logger_config{log_file_path};
    }
    
    # Inicializa arquivos de log
    $self->_initializeLogFiles();
}

# Inicializa arquivos de log
sub _initializeLogFiles {
    my ($self) = @_;
    
    return unless $logger_config{log_to_file};
    
    my $date = $self->_getCurrentDate();
    
    # Arquivo de log principal
    my $main_log_file = "$logger_config{log_file_path}/$logger_config{log_file_prefix}_$date.log";
    $self->_openLogFile('main', $main_log_file);
    
    # Arquivo de log de erros
    my $error_log_file = "$logger_config{log_file_path}/$logger_config{log_file_prefix}_errors_$date.log";
    $self->_openLogFile('error', $error_log_file);
    
    # Arquivo de log de performance
    if ($logger_config{enable_performance}) {
        my $perf_log_file = "$logger_config{log_file_path}/$logger_config{log_file_prefix}_performance_$date.log";
        $self->_openLogFile('performance', $perf_log_file);
    }
}

# Abre arquivo de log
sub _openLogFile {
    my ($self, $type, $file_path) = @_;
    
    # Fecha arquivo anterior se existir
    if (exists $log_files{$type} && defined $log_files{$type}) {
        close $log_files{$type};
    }
    
    # Abre novo arquivo
    open(my $fh, '>>', $file_path) or return 0;
    $log_files{$type} = $fh;
    
    # Define buffer automático
    select((select($fh), $| = 1)[0]);
    
    return 1;
}

# Obtém data atual formatada
sub _getCurrentDate {
    my ($self) = @_;
    
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time());
    return sprintf("%04d%02d%02d", $year + 1900, $mon + 1, $mday);
}

# Log principal
sub log {
    my ($self, $level, $message, $context) = @_;
    
    # Verifica se deve fazer log
    return if $level < $logger_config{log_level};
    
    # Prepara dados do log
    my $log_data = $self->_prepareLogData($level, $message, $context);
    
    # Faz log em diferentes formatos
    $self->_writeLog($log_data);
    
    # Atualiza estatísticas
    $self->_updateStats($log_data);
    
    # Rotaciona arquivos se necessário
    $self->_rotateLogFiles();
}

# Prepara dados do log
sub _prepareLogData {
    my ($self, $level, $message, $context) = @_;
    
    my ($sec, $usec) = gettimeofday();
    
    my $log_data = {
        timestamp => time(),
        timestamp_iso => $self->_formatTimestamp($sec, $usec),
        level => $LOG_LEVELS[$level],
        level_num => $level,
        message => $message,
        context => $context || {},
        logger_context => $self->{context},
        process_id => $$,
        memory_usage => $self->_getMemoryUsage()
    };
    
    # Adiciona contexto específico se habilitado
    if ($logger_config{enable_context}) {
        $log_data->{context} = { %{$log_data->{context}}, %{$self->{context}} };
    }
    
    return $log_data;
}

# Formata timestamp ISO
sub _formatTimestamp {
    my ($self, $sec, $usec) = @_;
    
    my ($sec2, $min, $hour, $mday, $mon, $year) = localtime($sec);
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02d.%06dZ", 
        $year + 1900, $mon + 1, $mday, $hour, $min, $sec2, $usec);
}

# Obtém uso de memória
sub _getMemoryUsage {
    # Implementação simples para Windows
    if ($^O eq 'MSWin32') {
        return 'N/A'; # Windows não tem /proc/meminfo
    }
    
    # Para sistemas Unix/Linux
    if (open(my $fh, '<', '/proc/meminfo')) {
        while (my $line = <$fh>) {
            if ($line =~ /MemTotal:\s+(\d+)/) {
                close $fh;
                return $1 . ' KB';
            }
        }
        close $fh;
    }
    
    return 'N/A';
}

# Escreve log
sub _writeLog {
    my ($self, $log_data) = @_;
    
    # Log para console
    if ($logger_config{log_to_console}) {
        $self->_writeConsoleLog($log_data);
    }
    
    # Log para arquivo
    if ($logger_config{log_to_file}) {
        $self->_writeFileLog($log_data);
    }
}

# Escreve log no console
sub _writeConsoleLog {
    my ($self, $log_data) = @_;
    
    my $console_message = sprintf("[%s] [%s] %s", 
        $log_data->{timestamp_iso},
        $log_data->{level},
        $log_data->{message}
    );
    
    # Adiciona contexto se relevante
    if ($logger_config{enable_context} && %{$log_data->{context}}) {
        $console_message .= " (Context: " . encode_json($log_data->{context}) . ")";
    }
    
    print $console_message . "\n";
}

# Escreve log no arquivo
sub _writeFileLog {
    my ($self, $log_data) = @_;
    
    # Determina tipo de arquivo baseado no nível
    my $file_type = 'main';
    if ($log_data->{level_num} >= LOG_ERROR) {
        $file_type = 'error';
    }
    
    return unless exists $log_files{$file_type};
    
    my $fh = $log_files{$file_type};
    
    # Formato JSON
    if ($logger_config{log_format} eq 'json' || $logger_config{log_format} eq 'both') {
        print $fh encode_json($log_data) . "\n";
    }
    
    # Formato texto
    if ($logger_config{log_format} eq 'text' || $logger_config{log_format} eq 'both') {
        my $text_log = sprintf("[%s] [%s] %s", 
            $log_data->{timestamp_iso},
            $log_data->{level},
            $log_data->{message}
        );
        
        if ($logger_config{enable_context} && %{$log_data->{context}}) {
            $text_log .= " Context: " . encode_json($log_data->{context});
        }
        
        print $fh $text_log . "\n";
    }
    
    # Log de performance separado
    if ($logger_config{enable_performance} && exists $log_data->{context}->{performance}) {
        if (exists $log_files{performance}) {
            print $log_files{performance} encode_json($log_data) . "\n";
        }
    }
}

# Atualiza estatísticas
sub _updateStats {
    my ($self, $log_data) = @_;
    
    $log_stats{total_logs}++;
    $log_stats{logs_by_level}{$log_data->{level}}++;
    
    # Estatísticas por contexto
    if (exists $log_data->{context}->{context_type}) {
        my $context_type = $log_data->{context}->{context_type};
        $log_stats{logs_by_context}{$context_type} ||= 0;
        $log_stats{logs_by_context}{$context_type}++;
    }
    
    # Métricas de performance
    if ($logger_config{enable_performance} && exists $log_data->{context}->{performance}) {
        my $perf = $log_data->{context}->{performance};
        foreach my $metric (keys %$perf) {
            $log_stats{performance_metrics}{$metric} ||= [];
            push @{$log_stats{performance_metrics}{$metric}}, $perf->{$metric};
            
            # Mantém apenas as últimas 100 métricas
            if (@{$log_stats{performance_metrics}{$metric}} > 100) {
                shift @{$log_stats{performance_metrics}{$metric}};
            }
        }
    }
}

# Rotaciona arquivos de log
sub _rotateLogFiles {
    my ($self) = @_;
    
    return unless $logger_config{log_to_file};
    
    foreach my $type (keys %log_files) {
        my $fh = $log_files{$type};
        next unless defined $fh;
        
        # Obtém tamanho do arquivo
        my $file_size = -s $fh;
        
        if ($file_size > $logger_config{max_file_size}) {
            $self->_rotateLogFile($type);
        }
    }
}

# Rotaciona arquivo de log específico
sub _rotateLogFile {
    my ($self, $type) = @_;
    
    my $fh = $log_files{$type};
    return unless defined $fh;
    
    close $fh;
    
    # Renomeia arquivo atual
    my $current_date = $self->_getCurrentDate();
    my $current_file = "$logger_config{log_file_path}/$logger_config{log_file_prefix}_${type}_$current_date.log";
    
    # Remove arquivos antigos
    $self->_cleanupOldLogFiles($type);
    
    # Abre novo arquivo
    $self->_openLogFile($type, $current_file);
}

# Remove arquivos de log antigos
sub _cleanupOldLogFiles {
    my ($self, $type) = @_;
    
    my $log_dir = $logger_config{log_file_path};
    my $prefix = "$logger_config{log_file_prefix}_${type}_";
    
    opendir(my $dh, $log_dir) or return;
    
    my @log_files = grep { /^$prefix.*\.log$/ } readdir($dh);
    closedir $dh;
    
    # Ordena por data (mais antigos primeiro)
    @log_files = sort @log_files;
    
    # Remove arquivos excedentes
    while (@log_files > $logger_config{max_files}) {
        my $old_file = shift @log_files;
        unlink "$log_dir/$old_file";
    }
}

# Métodos de conveniência para diferentes níveis
sub debug { shift->log(LOG_DEBUG, @_) }
sub info  { shift->log(LOG_INFO, @_) }
sub warn  { shift->log(LOG_WARN, @_) }
sub error { shift->log(LOG_ERROR, @_) }
sub fatal { shift->log(LOG_FATAL, @_) }

# Define contexto do logger
sub setContext {
    my ($self, $context) = @_;
    
    if (ref($context) eq 'HASH') {
        $self->{context} = { %{$self->{context}}, %$context };
    }
}

# Limpa contexto do logger
sub clearContext {
    my ($self) = @_;
    
    $self->{context} = {};
}

# Log de performance
sub logPerformance {
    my ($self, $operation, $duration, $context) = @_;
    
    my $perf_context = {
        performance => {
            operation => $operation,
            duration => $duration,
            timestamp => time()
        }
    };
    
    if ($context) {
        $perf_context = { %$perf_context, %$context };
    }
    
    $self->info("Performance: $operation took ${duration}s", $perf_context);
}

# Obtém estatísticas do logger
sub getStats {
    my ($self) = @_;
    
    return { %log_stats };
}

# Define configuração do logger
sub setConfig {
    my ($self, $key, $value) = @_;
    
    if (exists $logger_config{$key}) {
        $logger_config{$key} = $value;
        return 1;
    }
    
    return 0;
}

# Obtém configuração do logger
sub getConfig {
    my ($self, $key) = @_;
    
    return $logger_config{$key};
}

# Fecha todos os arquivos de log
sub close {
    my ($self) = @_;
    
    foreach my $type (keys %log_files) {
        if (defined $log_files{$type}) {
            close $log_files{$type};
            delete $log_files{$type};
        }
    }
}

# Destrutor
sub DESTROY {
    my ($self) = @_;
    
    $self->close();
}

1;
