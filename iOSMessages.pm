package iOSMessages;

use DBI;
use Data::Dumper;

sub new
{
    my ($class, $params) = @_;
    my $self = {
        _backup_directory => $params->{backup_directory},
        _sms_db_filename => '3d0d7e5fb2ce288813306e4d4636395e047a3d28',
        _sms_db => undef,
        _messages => {}
    };

    unless (-d $self->{_backup_directory}){
        print "direcotry " . $self->{_backup_directory} . "\n";
        die 'Directory does not exist';
    }
    
    bless $self, $class;
    return $self;
}

sub get_messages{
    my ($self) = @_;
    $self->_generate_messages_hash;
}

# Internal methods 
sub _db {
    my ($self) = @_;

    return $self->{_sms_db} if ($self->{_sms_db});

    $self->{_sms_db} = DBI->connect( 
        "dbi:SQLite:dbname=".$self->{_backup_directory}.$self->{_sms_db_filename}, 
        "",                          
        "",                          
        { RaiseError => 1 },         
    ) or die $DBI::errstr;
    return $self->{_sms_db};
}

sub _generate_messages_hash {
    my ($self) = @_;

    my $dbh = $self->_db;
    my $query = qq|        
        SELECT 
            m.rowid as RowID,
            h.id AS UniqueID, 
            CASE is_from_me 
                WHEN 0 THEN "received" 
                WHEN 1 THEN "sent" 
                ELSE "Unknown" 
            END as Type, 
            CASE 
                WHEN date > 0 then TIME(date + 978307200, 'unixepoch', 'localtime')
                ELSE NULL
            END as Time,
            CASE 
                WHEN date > 0 THEN strftime('%Y%m%d', date + 978307200, 'unixepoch', 'localtime')
                ELSE NULL
            END as Date, 
            text as Text,
            maj.attachment_id 
        FROM message m
        LEFT JOIN handle h ON h.rowid = m.handle_id
        LEFT JOIN message_attachment_join maj
        ON maj.message_id = m.rowid
        ORDER BY UniqueID, Date, Time LIMIT 40|;
    my $sth = $dbh->prepare($query);
    $sth->execute();
    
    my $tempMessages = {};
    
    while (my $text = $sth->fetchrow_hashref){
        if (my $uniqueID = $text->{'UniqueID'}) {
            my $uniqueID = $text->{'UniqueID'};
            push @{$tempMessages->{$uniqueID}}, $text;
        }
    }
    $self->{_messages} = $tempMessages;
    print Dumper $tempMessages; 
}

1;
