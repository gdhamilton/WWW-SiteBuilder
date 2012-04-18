package WWW::SiteBuilder;
# VERSION

use Mouse;
use Carp qw/croak/;
use v5.14;
use SOAP::Lite;  
#use SOAP::Lite +trace => 'all';
use Data::Dumper::Concise;
use YAML qw/LoadFile/;

use vars '$AUTOLOAD';

# map calls to services	-- theres gotta be a better way to do this
our %SB_CALL = ();
foreach (qw(
		CreateAccount CreateAccountWithNewPlan DeleteAccount
		FindAccount GetAccountById GetAccountByName 
		SetAccountStatus UpdateAccount UpdateProfile
)) { $SB_CALL{$_} = 'AccountWebService' };
foreach (qw(
		ActivateHost CreateHost DeleteHost FindHosts
		GetHostByAddress GetHostById UpdateHost
)) { $SB_CALL{$_} = 'HostWebService' };
foreach (qw(
		AddHostsAsIpAddressesToAccountPlan AddHostToPlan
		CanAddAccount CanAddHost CanAddSite CanAddSiteByUser
		CreatePlan Delete DeleteHostsAsIpAddressesFromAccountPlan
		FindPlans GetAvailablePlans GetCurrentPlan GetPlanById
		GetPlanBySite SetActive SetAnonymous UpdateLicense
		UpdatePlan UpdatePlanPermissions
)) { $SB_CALL{$_} = 'PlanWebService' };
foreach (qw(
		ActivateSite ChangeSiteOwner CreateAnonymousSite 
		CreateSite CreateSite2 CreateSiteWithHost
		DeleteExpiredAnonymouseSites DeleteSite FindSites
		GetPublishSiteStatus GetSiteById GetSiteHost
		IsAnonymousSite MigrateSiteWithHost PublishSite
		TakeOwnershipOfAnonymousSite UpdateSite
		UpdateSiteLastPublishingSettings UpdateSiteWithHost
)) { $SB_CALL{$_} = 'SiteWebService' };
foreach (qw(
		AddDelegationRule DeleteDelegationRule DeleteSsoRelay
		DisableSso FindSiteFamilies GetAdvertisingSettings
		GetAdvertisingSettingsBySite GetBaseApplicationUrl
		GetDefaultSsoRelay GetLanguages GetLicenseInfo
		GetModules GetPagesets GetPlatform GetSkins
		GetSshKey GetSsoRelay GetSsoServer GetTemplates
		GetVersionApi GetVersionSiteBuilder ImportLicense
		SetAdvertisingSettings SetBaseApplicationUrl SetDefaultSsoRelay
		SetSkinStatus SetSsoRelay SetSsoServer
)) { $SB_CALL{$_} = 'SystemWebService' };
	
has 'server' => (
	is => 'rw',
	isa => 'Str',
	required => 0,
);

has 'username' => (
    is => 'rw',
    isa => 'Str',
    required => 0	
);

has 'password' => (
    is => 'rw',
    isa => 'Str',
    required => 0
);

has 'config' => (
	is => 'rw',
	isa => 'Str | HashRef[Str]',
	required => 0,
);

has 'debug' => (
    is => 'rw',
    isa => 'Bool',
    required => 0,
    default => 0
);

has 'sb_version' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    default => '4.5'
);

sub BUILD {
	my ($self, $params) = @_;
	if ($params->{config}) {
		unless ($self->config($params->{config})) {
			warn "failed to load configuration in $$params{config}";
		}
	}
	else {
		my @fields = qw/username password server/;
		foreach my $k (@fields) {
			unless (defined $$params{$k} and length $$params{$k}) {
				croak "" . ref($self) . " requires " . join(', ', @fields) . " (or 'config' with valid config)";
			}
		}
		$self->server($$params{server});
		$self->username($$params{username});
		$self->password($$params{password});
	}
}

after 'config' => sub {
	my ($self, $value) = @_;
	my $cfg;
	
	eval { $cfg = LoadFile($value); };
	if ($@) { warn "failed to open config file $value:\n$@"; return undef; }
	
	foreach my $k (qw/username password server/) {
		unless (defined $$cfg{$k} and length $$cfg{$k}) {
			croak "config hash requires '$k' to be set, aborting";
		}
	}
	$self->server($$cfg{server});
	$self->username($$cfg{username});
	$self->password($$cfg{password});
	$self->sb_version($$cfg{sb_version} || '4.5'); 
};

sub _client {
	my ($self, $method) = @_;
	unless (defined $method and exists $SB_CALL{$method}) {
		warn "_client called without specifying method";
		return undef;
	}
	unless ($self->server) {
		warn "_client called without 'server' attribute defined";
		warn Dumper $self;
		return undef;
	}

	my $endpoint = sprintf('http://%s/ServiceFacade/%s/%s.asmx', 
							$self->server, $self->sb_version, $SB_CALL{$method});

	return SOAP::Lite->readable(1)
    	->serializer( WWW::SiteBuilder::Serializer->new )
    	->on_action( sub { return '""' } )->multirefinplace(1)
    	->default_ns($self->_method_ns($method))
    	->proxy($endpoint);
}

sub _build_header {
	my ($self, $method) = @_;
	unless (defined $method) {
		warn "_build_header called without method param";
		return undef;
	}
	unless ($self->username and $self->password) {
		warn "_build_header called with undefined username and password attributes";
		return undef;
	}

	return SOAP::Header->uri($self->_method_ns($method))
		->name('CredentialsSoapHeader')->value(
			\SOAP::Header->value(
				SOAP::Header->name('Login' => $self->username),
				SOAP::Header->name('Password' => $self->password)
			),
		);
}

sub _build_tag {
	my ($self, $tag, $content) = @_;
	
#	return undef unless defined $content;

	if (! ref($content)) { # scalar
		return SOAP::Data->name($tag => $content) unless $tag eq "string";
		return SOAP::Data->type('string')->name($tag => $content);
	}
	elsif (ref $content eq "ARRAY") {
		my @elems = ();
		foreach (@$content) {

			#push @elems, $self->_build_tag($tag, $v);
			push @elems, ( ref $_ ? $self->_build_tag( $tag, $_ ) : 
						 			$self->_build_tag( "string" , $_ ));
		}

		return SOAP::Data->name($tag => \SOAP::Data->value(@elems));
	}
	elsif (ref $content eq "HASH") {
		my @elems = ();
		foreach my $k (keys %$content) {
			push @elems, $self->_build_tag($k, $$content{$k});
		}
		return SOAP::Data->name($tag)->value(
			\SOAP::Data->value(@elems)
		);
	}
	return undef; # shouldnt be here
}

sub _call {
	my $self = shift;
	my $method = shift;

	my (%params) = @_;

	if ($method =~ /^[a-z_]+$/) { # method_style
		$method = join '', map { ucfirst($_) } split(/_/, $method); # MethodStyle
	}

	my $client = $self->_client($method);
	unless ($client) {
		warn "call($method) couldn't build client";
		return undef;
	}

	my $raw_flag = delete $params{RAW};

	my @elems = map { $self->_build_tag($_, $params{$_}); } sort keys %params;

	my $method_tag = SOAP::Data->name($method)
		->uri($self->_method_ns($method));

	my $r = $client->call(
		$method_tag => SOAP::Data->value(@elems),
		$self->_build_header($method)
	);

	unless ($r) {
		warn ref $self . ": $method call failed, SOAP::Lite returned bad value";
		return undef;
	}

	if ($r->fault) {
		warn $r->faultstring;
		return undef;
	}
	
	# if RAW is set in call, return only the METHODNAMEResponse object if present, raw response otherwise
	return ($r->valueof(sprintf("//%sResponse", $method)) || $r) if $raw_flag;

	# return the deepest thing we can find, fallback to the raw response object
	return 	$r->valueof(sprintf("//%sResponse/%sResult/Items", $method, $method)) ||
			$r->valueof(sprintf("//%sResponse/%sResult", $method, $method)) ||
			$r->valueof(sprintf("//%sResponse", $method)) || 
			$r;
}

sub _method_ns {
	my ($self, $method) = @_;
	my $svc = $SB_CALL{$method};
	unless (defined $svc) {
		warn "cannot compute SOAP namespace without service name";
		return undef;
	}
	my $uri_stem = 'http://swsoft.com/webservices/sb/%s/%s';
	my $suffix = $svc =~ s|Web||r || undef; # condition hack to fix syntax highliter
	return sprintf($uri_stem, $self->sb_version, $suffix);
}

sub AUTOLOAD {
	(my $method = $AUTOLOAD) =~ s/.*:://s; # get just the method basename

	if ($method =~ /^[a-z_]+$/) {
		$method = join '', map { ucfirst($_) } split(/_/, $method);
	}

	my $self = shift;
	my (%params) = @_;

	unless (defined $SB_CALL{$method}) {
		warn "Nonexistent method $method called - doing nothing";
		print Dumper \%SB_CALL;
		return undef;
	}

	$self->_call($method, %params);
}

# ABSTRACT: Perl interface to Parallels (SWsoft) SiteBuilder 4.5
=head1 SYNOPSIS
Please see the official SiteBuilder API documentation for a full list of methods:
* L<http://download1.parallels.com/SiteBuilder/4.5.0/doc/api/dev_guide/en_US/html/|SiteBuilder 4.5>
* L<http://www.parallels.com/ptn/documentation/sitebuilder/|SiteBuilder API documentation index>
=cut
1;

no Mouse;

package WWW::SiteBuilder::Serializer;

use strict;
use warnings;
use SOAP::Lite;

use vars qw( @ISA );
@ISA = qw( SOAP::Serializer );

sub encode_object {
    my ( $self, $object, $name, $type, $attr ) = @_;

    if ( defined $attr->{'xsi:nil'} ) {
        delete $attr->{'xsi:nil'};
        return [ $name, {%$attr} ];
    }
    return $self->SUPER::encode_object( $object, $name, $type, $attr );
}

1;

# my %params = (name => 'test thing', templateIds => ['abc','def','ghi']);
