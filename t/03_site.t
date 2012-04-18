use Test::More;
use Data::Dumper::Concise;
use WWW::SiteBuilder;

my $now = time;
my $UUID_REGEX = qr/^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/;

my $sb = WWW::SiteBuilder->new(config => $ENV{SB_CONFIG});
isa_ok($sb, 'WWW::SiteBuilder');

# get the current user id
my $r_find_account = $sb->GetAccountByName(
	username => $sb->username
);

# create the site -- omg so easy
my $domain = "sbtest$now.dev-hosts.us";
my $r_create_site = $sb->CreateSite(
	siteType => 'Regular',
	siteAlias => $domain,
	ownerId => $$r_find_account{UserAccount}->{AccountId}
);

is($$r_create_site{Alias}, $domain, "create site under current user successfully");

# delete the site

my $r_delete_site = $sb->DeleteSite(
	siteIds => [ $$r_create_site{Id} ]
);

my $sr_delete_site = $$r_delete_site{ServiceDeleteResultOfSiteDeleteStatus};

is($$sr_delete_site{Id}, $$r_create_site{Id}, "delete first site and receive correct ID in response");
is($$sr_delete_site{Status}, 'Deleted', "DeleteSite response has status 'deleted'");

# create site with host
my $hosted_domain = "sbtest$now.dev-hosted.us";
my $r_create_site2 = $sb->CreateSiteWithHost(
	ownerId => $$r_find_account{UserAccount}->{AccountId},
	alias => $hosted_domain,
	ipAddress => "127.0.0.1",
	publishUsername => "defaultsite",
	publishPassword => $sb->password,
	publishWorkingDirectory => '/httpdocs',
	publishWebSiteUrl => "http://${hosted_domain}/"
);

is($$r_create_site2{Alias}, $hosted_domain, "create hosted site successfully");
is($$r_create_site2{PublishingSettings}->{StandardLocation}->{Address}, '127.0.0.1', 
	"CreateSiteWithHost response contains same address as given in request");

# cleanup
$r_delete_site = $sb->DeleteSite(
	siteIds => [ $$r_create_site2{Id} ]
);

$sr_delete_site = $$r_delete_site{ServiceDeleteResultOfSiteDeleteStatus};

is($$sr_delete_site{Id}, $$r_create_site2{Id}, "delete second site and receive correct ID in response");
is($$sr_delete_site{Status}, 'Deleted', "DeleteSite response has status 'deleted'");

done_testing;
