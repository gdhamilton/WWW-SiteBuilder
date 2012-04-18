use Test::More;
use Data::Dumper::Concise;
use WWW::SiteBuilder;

my $sb = WWW::SiteBuilder->new(config => $ENV{SB_CONFIG});
isa_ok($sb, 'WWW::SiteBuilder');

my $now = time;
my $UUID_REGEX = qr/^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/;

# first we have to get the valid families...
my $r_families = $sb->FindSiteFamilies(
	criteria => '',
	pos => 0,
	count => 10,
	'select' => 'Administrator',
	sortType => 'Code',
	sortDirection => 'Ascending',
	language => 'en'
);

# ..and pick the "generic" family id.
my $family_obj = \grep { $$_{'Code'} eq 'generic' } @{$$r_families{SiteFamilyValue}};
my $family_id = $$$family_obj{Id};

like($family_id, $UUID_REGEX, "family ID is a valid UUID");

# now we have to get the valid pagesets...
my @r_pagesets = map { $$_{Code} } @{$sb->GetPagesets()->{PagesetValue}};
# .. and trust that it worked...
my @check_pagesets = grep { defined $_ } @r_pagesets;
ok(@check_pagesets == @r_pagesets, "GetPagesets returns a non-empty list of defined values");

# create a plan: 

my $plan_name = "WWWSB_$now";
my %create_plan_data = (
	name				=> $plan_name,
	description 		=> "",

	maxPagesNumber 					=> '1',
	maxPagesRootLevel 				=> '1',
	maxPagesLevel 					=> '1',
	maxSitesNumber 					=> '1',
	maxAccountsNumber 				=> '0',
	maxHostsNumber 					=> '0',
	isPersonal => 'false',
	isAnonymous => 'false',
	
	trialLifeTime 					=> '30',
	trialLifeType					=> 'Days',
	pagesetsIds 					=> \@r_pagesets,
	families 						=> [ $family_id ],
	defaultFamily 					=> $family_id,
	isPublishingSettingsEditable 	=> 'true',
	isFtpPublishAvailable 			=> 'true',
	isXcopyPublishAvailable 		=> 'true',
	isVpsPublishAvailable 			=> 'true',
	isAdditionalSiteContentAllowed 	=> 'false',
	isUserManagementAllowed 		=> 'true',
	isSiteManagementAllowed 		=> 'true',
);

my $r_create_plan = $sb->CreatePlan( %create_plan_data );

is($$r_create_plan{Name}, $plan_name, "CreatePlan response contains correct Name of plan as passed in request");

# test querying the plan we created
my $r_find_plans = $sb->FindPlans(
	criteria => "WWWSB_$now", 
	startPos => 0,
	count => 1,
	sortField => 'Id',
	sortDirection => 'Ascending',
	showPersonal => 'false'
);

is($$r_find_plans{PlanValue}->{Name}, $plan_name, "FindPlans is able to locate created plan using Name as criteria");

# delete the plan
my $r_del_plan = $sb->Delete(
	planIDs => [ $$r_create_plan{PlanId} ]
);

is($$r_del_plan{ServiceDeleteResultOfPlanDeleteStatus}->{ItemName}, $plan_name, "Delete created plan successfully");

my $r_find_plans = $sb->FindPlans(
	criteria => "WWWSB_$now", 
	startPos => 0,
	count => 1,
	sortField => 'Id',
	sortDirection => 'Ascending',
	showPersonal => 'false'
);

is($$r_find_plans{TotalCount}, 0, "FindPlans returns 0 items with deleted plan name");

done_testing;
