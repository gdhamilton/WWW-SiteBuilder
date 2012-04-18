use Test::Most;
use Test::Exception;
use Data::Dumper::Concise;
use YAML qw /LoadFile/;
bail_on_fail; 

ok(defined $ENV{SB_CONFIG}, 'SB_CONFIG environment variable is set') or 
	diag('Please set SB_CONFIG to the path to a valid YAML config file');
my $cfg = stat $ENV{SB_CONFIG} ? LoadFile($ENV{SB_CONFIG}) : {};

ok(defined $$cfg{server}, "server config var is set");
ok(defined $$cfg{username}, "username config var is set");
ok(defined $$cfg{password}, "password config var is set");

require_ok 'WWW::SiteBuilder';

restore_fail;

my $sb;

throws_ok { $sb = WWW::SiteBuilder->new() } qr/WWW::SiteBuilder requires username, password, server/,
	"creating SiteBuilder object without params should croak";

$sb = WWW::SiteBuilder->new(
	server => $$cfg{server},
	username => $$cfg{username},
	password => $$cfg{password},
);

isa_ok($sb, 'WWW::SiteBuilder');
is($sb->server, $$cfg{server}, "object's server attrib matches environment");
is($sb->username, $$cfg{username}, "object's username attrib matches environment");
is($sb->password, $$cfg{password}, "object's password attrib matches environment");



done_testing;
