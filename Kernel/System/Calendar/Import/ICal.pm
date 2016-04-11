# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Calendar::Import::ICal;

use strict;
use warnings;

use Data::ICal;
use Data::ICal::Entry::Event;
use Date::ICal;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::Calendar',
    'Kernel::System::Calendar::Appointment',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Time',
);

=head1 NAME

Kernel::System::Calendar::Import::ICal - iCalendar import lib

=head1 SYNOPSIS

Import functions for iCalendar format.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ImportObject = $Kernel::OM->Get('Kernel::System::Calendar::Export::ICal');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

=item Import()

import calendar in iCalendar format
    my $Success = $ImportObject->Import(
        CalendarID   => 123,
        ICal         =>                         # (required) iCal string
            '
                BEGIN:VCALENDAR
                PRODID:Zimbra-Calendar-Provider
                VERSION:2.0
                METHOD:REQUEST
                ...
            ',
        UserID       => 1,                      # (required) UserID
    );
returns 1 if successful

=cut

sub Import {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(CalendarID ICal UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $Calendar = Data::ICal->new( data => $Param{ICal} );

    # my $ICalObject = iCal::Parser->new();

    # my $Ical = $ICalObject->parse_strings([ $Param{ICal} ]);
    my @Entries = @{ $Calendar->entries() };

    for my $Entry (@Entries) {
        my $Properties = $Entry->properties();

        my %Parameters;

        # get title
        if ( $Properties->{'summary'} && ref $Properties->{'summary'} eq "ARRAY" ) {
            if (
                scalar @{ $Properties->{'summary'} } > 0
                &&
                $Properties->{'summary'}->[0]->{'value'}
                )
            {
                $Parameters{Title} = $Properties->{'summary'}->[0]->{'value'};
            }
        }

        # get description
        if ( $Properties->{'description'} && ref $Properties->{'description'} eq "ARRAY" ) {
            if (
                scalar @{ $Properties->{'description'} } > 0
                &&
                $Properties->{'description'}->[0]->{'value'}
                )
            {
                $Parameters{Description} = $Properties->{'description'}->[0]->{'value'};
            }
        }

        # get start time
        if ( $Properties->{'dtstart'} && ref $Properties->{'dtstart'} eq "ARRAY" ) {
            if (
                scalar @{ $Properties->{'dtstart'} } > 0
                &&
                $Properties->{'dtstart'}->[0]->{'value'}
                )
            {
                my $StartTime = $Properties->{'dtstart'}->[0]->{'value'};

                $Parameters{StartTime} = $Self->_FormatTime(
                    Time => $StartTime,
                );

            }
        }

        # get end time
        if ( $Properties->{'dtend'} && ref $Properties->{'dtend'} eq "ARRAY" ) {
            if (
                scalar @{ $Properties->{'dtend'} } > 0
                &&
                $Properties->{'dtend'}->[0]->{'value'}
                )
            {
                my $EndTime = $Properties->{'dtend'}->[0]->{'value'};

                $Parameters{EndTime} = $Self->_FormatTime(
                    Time => $EndTime,
                );

            }
        }

        # use Data::Dumper;
        # my $Data2 = Dumper( \$Properties);
        # open(my $fh, '>>', '/opt/otrs-test/data.txt') or die 'Could not open file ';
        # print $fh "\n==========================\n" . $Data2;
        # close $fh;

        # use Data::Dumper;
        # my $Data2 = Dumper( \%Parameters);
        # open(my $fh, '>>', '/opt/otrs-test/data.txt') or die 'Could not open file ';
        # print $fh "\n==========================\n" . $Data2;
        # close $fh;

#  my $AppointmentID = $AppointmentObject->AppointmentCreate(
#     CalendarID          => $Param{CalendarID},
#     Title               => 'Webinar',                               # (required) Title
#     Description         => 'How to use Process tickets...',         # (optional) Description
#     Location            => 'Straubing',                             # (optional) Location
#     StartTime           => '2016-01-01 16:00:00',                   # (required)
#     EndTime             => '2016-01-01 17:00:00',                   # (required)
#     AllDay              => 0,                                       # (optional) Default 0
#     TimezoneID          => 1,                                       # (required) Timezone - it can be 0 (UTC)
#     Recurring           => 1,                                       # (optional) Flag the appointment as recurring (parent only!)
#     RecurrenceFrequency => 1,                                       # (optional)
#     RecurrenceCount     => 1,                                       # (optional)
#     RecurrenceInterval  => 2,                                       # (optional)
#     RecurrenceUntil     => '2016-01-10 00:00:00',                   # (optional)
#     RecurrenceByMonth   => 2,                                       # (optional)
#     RecurrenceByDay     => 5,                                       # (optional)
#     UserID              => 1,                                       # (required) UserID
# );

    }

    return 1;
}

sub _FormatTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Time)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my $TimeStamp;

    if ( $Param{Time} =~ /(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})/i ) {

        # format string
        $TimeStamp = "$1-$2-$3 $4:$5:$6";
    }

    return $TimeStamp;

}

# no warnings 'redefine';

# sub Data::ICal::product_id {    ## no critic
#     return 'OTRS ' . $Kernel::OM->Get('Kernel::Config')->Get('Version');
# }

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not
