use Test::More;
use Digest::MD5 qw/md5_hex/;
use Data::Dumper::Concise;

my $now = time;
my $cfg_file = $ENV{'SB_CONFIG'} || undef; 
my $UUID_REGEX = qr/^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/;

unless (stat $cfg_file) {
	plan skip_all => 'Cannot test functionality without SiteBuilder login credentials';
}

require_ok 'WWW::SiteBuilder';

# try loading config from SB_API_CONFIG env variable; defaults to 'sb.yml' in current directory
my $sb = WWW::SiteBuilder->new(config => $cfg_file);
isa_ok $sb, 'WWW::SiteBuilder';

# locate our own account
my $own_account = $sb->find_account(
	criteria => $sb->username, 
	startPos => '0', 
	count => '1', 
	sortField => 'UserName', 
	sortDirection => 'Ascending'
)->{AccountValue};

is($$own_account{UserName}, 'admin',  "FindAccount with our own username returns ");

# create a basic SiteOwner account
my $username = "t${now}";
my $password = md5_hex($now);

# get the ID for the 'Default plan'
my $plan_name = 'Default plan';
my ($plan) = grep { $$_{Name} eq $plan_name } @{$sb->get_available_plans()->{PlanValue}};

like($$plan{PlanId}, $UUID_REGEX, "find ID of default plan");



my $r_create_acct = $sb->create_account(
#	ownerAccountId			=> '',
	username 				=> $username,
	password 				=> $password,
	firstName 				=> 'WWW',
	lastName 				=> 'SiteBuilder',
	email 					=> 'wwwsbtest@example.com',
	role 					=> 'SiteOwner',
	planId 					=> $$plan{PlanId},
	changePasswordAllowed 	=> 'true',
);

ok(defined $r_create_acct, "create a basic SiteOwner account and receive a response");

# update the name on the created account

# change the language code to French

# search for the account's details

done_testing();

