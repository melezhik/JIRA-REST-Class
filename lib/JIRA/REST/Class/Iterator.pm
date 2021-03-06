package JIRA::REST::Class::Iterator;
use base qw( JIRA::REST::Class::Abstract );
use strict;
use warnings;
use v5.10;

our $VERSION = '0.01';

# ABSTRACT: A helper class for C<JIRA::REST::Class> that represents a JIRA query as an object.  Allows the user to iterate over the results and retrieve them one by one.

__PACKAGE__->mk_accessors(qw( total
                              fetched
                              iterator_args
                              restart_if_lt_total
                              seen_cache ));

sub init {
    my $self = shift;
    $self->SUPER::init(@_);

    my $args = $self->iterator_args;

    # if we weren't passed a maxResults, use the default for the class object
    unless (exists $args->{maxResults}) {
        $args->{maxResults} = $self->jira->maxResults;
    }

    if (exists $args->{restart_if_lt_total}) {
        $self->restart_if_lt_total($args->{restart_if_lt_total});
        delete $args->{restart_if_lt_total};
    }

    $self->seen_cache({});
    $self->fetched(0);
    $self->set_search_iterator; # fetch the first bunch of issues
}


=method B<issue_count>

A count of the number of issues matched by the query.

=cut

sub issue_count { shift->total }

=method B<next>

The next issue returned by the query, as a C<JIRA::REST::Class::Issue> object.  If there are no more issues matched by the query, this method returns an undefined value.

If the 'restart_if_lt_total' method is set to true and the number of issues fetched is less than the total number of issues matched by the query (see the B<issue_count> method), this method will rerun the query and keep returning issues. This is particularly useful if you are transforming a number of issues through an iterator, and the transformation causes the issues to no longer match the query.

=cut

sub next {
    my $self = shift;

    my $issue = $self->_get_next_unseen_issue;

    if (! $issue && $self->fetched < $self->total &&
        $self->restart_if_lt_total) {

        # ok, we didn't get as many results as we were promised,
        # so let's try the search again
        $self->set_search_iterator;
        $issue = $self->_get_next_unseen_issue;
    }

    if ( $issue ) {
        $self->fetched($self->fetched + 1);
        return $self->factory->make_object('issue', { data => $issue });
    }

    return;
}


=internal_method B<_get_next_unseen_issue>

Method to consolidate code that fetches issues without duplication

=cut

sub _get_next_unseen_issue {
    my $self  = shift;
    my $issue = $self->JIRA_REST->next_issue;

    # loop if we got an issue but we've seen it already
    while ( $issue && $self->seen_cache->{ $issue->{id} }++ ) {
        $issue = $self->JIRA_REST->next_issue;
    }

    return $issue;
}

=method B<restart_if_lt_total>

This accessor tells the iterator whether to restart the search if the number of issues found is less than the issue count returned by the initial search.

=cut


=internal_method B<set_search_iterator>

Method that is used to restart a query that has run out of results prematurely.

=cut

sub set_search_iterator {
    my $self = shift;
    my $args = shift || $self->iterator_args;

    $self->JIRA_REST->set_search_iterator($args);

    # fetch results using code borrowed from JIRA::REST
    my $iter = $self->JIRA_REST->{iter};
    $iter->{params}{startAt} = $iter->{offset};
    $iter->{results}         = $self->JIRA_REST->POST('/search', undef,
                                                      $iter->{params});

    # since there seems to be a problem with getting all the results in one
    # search, let's track how many we get so we can re-search if necessary
    $self->{total} = $self->JIRA_REST->{iter}->{results}->{total};
    $self->{fetched} = 0;
}

1;
