package JIRA::REST::Class::Query;
use base qw( JIRA::REST::Class::Abstract );
use strict;
use warnings;
use v5.10;

our $VERSION = '0.01';

# ABSTRACT: A helper class for C<JIRA::REST::Class> that represents a JIRA query as an object.  Attempts to return an array of all results from the query.


=method B<issue_count>

A count of the number of issues matched by the query.

=cut

sub issue_count { shift->data->{total} }

=method B<issues>

Returns a list of C<JIRA::REST::Class::Issue> objects matching the query.

=cut

sub issues {
    my $self = shift;
    my @issues = map {
        $self->factory->make_object('issue', { data => $_ });
    } @{ $self->data->{issues} };
    return @issues;
}

1;
