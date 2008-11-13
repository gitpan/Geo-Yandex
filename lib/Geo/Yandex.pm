package Geo::Yandex;

use vars qw ($VERSION);
$VERSION = '0.1';

my $API = 'geocode-maps.yandex.ru/1.x';

use strict;
use utf8;
use Geo::Yandex::Location;
use LWP::UserAgent;
use URI::Escape;
use XML::LibXML;

sub new {
    my ($class, $key) = @_;
    
    unless ($key) {
        warn "API key is not specified\n";
        return undef;
    }

    my $this = {
        key => $key,
        error => '',
    };
    
    bless $this, $class;
    
    return $this;
}

sub location {
    my ($this, %data) = @_;

    $this->{'error'} = '';

    unless ($data{'address'} && $this->{'key'}) {
        $this->{'error'} = "Either address or API key are not specified\n";
        return undef;
    }
    
    my $uri
        = "http://$API/?key=" . uri_escape_utf8($this->{'key'})
        . '&geocode=' . uri_escape_utf8($data{'address'});

    my $useragent = new LWP::UserAgent;
    my $request = new HTTP::Request(GET => $uri);
    my $response = $useragent->request($request);

    if ($response->is_success) {
        return $this->parse_response($response->content);        
    }
    else {
        $this->{'error'} = "HTTP request error: " . $response->status_line . "\n";
        return undef;
    }    
}

sub parse_response {
    my ($this, $content) = @_;

    my $parser = new XML::LibXML;
    my $xml = $parser->parse_string($content);
    
    my $context = new XML::LibXML::XPathContext;
    $context->registerNs('ymaps', 'http://maps.yandex.ru/ymaps/1.x');
    $context->registerNs('gml', 'http://www.opengis.net/gml');
    $context->registerNs('xal', 'urn:oasis:names:tc:ciq:xsdschema:xAL:2.0');
    $context->registerNs('ygeo', 'http://maps.yandex.ru/geocoder/1.x');
    
    my $ymaps = ${$context->findnodes('/ymaps:ymaps', $xml)}[0];
    my $request = ${$context->findnodes('.//ygeo:request', $ymaps)}[0]->textContent;
    my $found = ${$context->findnodes('.//ygeo:found', $ymaps)}[0]->textContent;

    return () unless $found;

    my @featureMembers = $context->findnodes('.//gml:featureMember', $ymaps);
    my @ret;
    foreach my $featureMember (@featureMembers) {
        push @ret, new Geo::Yandex::Location($context, $featureMember);
    }
    
    return @ret;
}

1;

__END__

=encoding utf-8

=head1 NAME

Geo::Yandex - Performs geographical queries using Yandex Maps API

=head1 SYNOPSIS

    # Address to search
    my $addr = 'Москва, Красная площадь, 1';
    
    # Personal API key, should be obtained at http://api.yandex.ru/maps/form.xml
    my $key = '. . .';
    
    # New geo object, note to use the key
    my $geo = new Geo::Yandex($key);
    
    # Search locations with a given address
    my @locations = $geo->location(address => $addr);
    
    # Locations are an array of Geo::Yandex::Location elements
    for my $item (@locations) {
        printf "%s\n", $item->address;
        printf "\t%s, %s (%s)\n", $item->latitude, $item->longitude, $item->kind;
    }

    
=head1 ABSTRACT

Geo::Yandex is a Perl interface for the part of Yandex Maps API which retrieves geographical data for text query.

=head1 DESCRIPTION

Yandex Maps API is a set of tools for working with http://maps.yandex.ru website both with JavaScript queries and HTTP negotiations. Full description of the interface can be found at http://api.yandex.ru/maps/doc/ (in Russian).

All the work is done by an instance of Geo::Yandex class.

=head2 new
 
Creates a new Geo::Yandex object. The only argument, which is required, is a personal key that should be issued by Yandex before using API. To obtain the key you need to fill the form at http://api.yandex.ru/maps/form.xml.

    my $geo = new Geo::Yandex($key);
    
=head2 location
    
    Launches search query to Yandex and returns the list of locations which match to the given address (passed in C<address> parameter).
    
    my @locations = $geo->location(address => $addr);
    
    The list returned by this method is combined of elements of the type Geo::Yandex::Location. If no results were found, return is an empty list.

=head1 AUTHOR

Andrew Shitov, <andy@shitov.ru>

=head1 COPYRIGHT AND LICENCE

Geo::Yandex module is a free software.
You may redistribute and (or) modify it under the same terms as Perl, whichever version it is.

=cut
