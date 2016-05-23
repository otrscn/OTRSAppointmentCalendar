# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentAppointmentCalendarOverview;

use strict;
use warnings;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get needed objects
    my $LayoutObject   = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CalendarObject = $Kernel::OM->Get('Kernel::System::Calendar');

    # get all user's valid calendars
    my $ValidID = $Kernel::OM->Get('Kernel::System::Valid')->ValidLookup(
        Valid => 'valid',
    );
    my @Calendars = $CalendarObject->CalendarList(
        UserID  => $Self->{UserID},
        ValidID => $ValidID,
    );

    # check if we found some
    if (@Calendars) {

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        $LayoutObject->Block(
            Name => 'CalendarDiv',
            Data => {
                %Param,
                CalendarWidth => 100,
            },
        );

        $LayoutObject->Block(
            Name => 'CalendarWidget',
        );

        my $CalendarLimit  = int $ConfigObject->Get('AppointmentCalendar::CalendarLimitOverview') || 10;
        my $CalendarColors = $ConfigObject->Get('AppointmentCalendar::CalendarColors')            ||
            [ '#3A87AD', '#EC9073', '#6BAD54', '#78A7FC', '#DFC01B', '#43B261', '#53758D' ];

        my $CalendarColorID = 0;
        my $CurrentCalendar = 1;
        for my $Calendar (@Calendars) {

            # current calendar color (sequential)
            $Calendar->{CalendarColor} = $CalendarColors->[$CalendarColorID];

            # check calendar by default if limit is not yet reached
            $Calendar->{Checked} = 'checked="checked" ' if $CurrentCalendar <= $CalendarLimit;

            # calendar checkbox in the widget
            $LayoutObject->Block(
                Name => 'CalendarSwitch',
                Data => {
                    %{$Calendar},
                    %Param,
                },
            );

            # calendar source (JSON)
            $LayoutObject->Block(
                Name => 'CalendarSource',
                Data => {
                    %{$Calendar},
                    %Param,
                },
            );
            $LayoutObject->Block(
                Name => 'CalendarSourceComma',
            ) if $CurrentCalendar < scalar @Calendars;

            # restart using the color array if needed
            $CalendarColorID = $CalendarColors->[ $CalendarColorID + 1 ] ? $CalendarColorID + 1 : 0;

            $CurrentCalendar++;
        }

        # get user preferences
        my %Preferences = $Kernel::OM->Get('Kernel::System::User')->GetPreferences(
            UserID => $Self->{UserID},
        );

        # set initial view
        $Param{DefaultView} = $Preferences{UserCalendarOverviewDefaultView} // 'timelineWeek';

        # get plugin list
        $Param{PluginList} = $Kernel::OM->Get('Kernel::System::Calendar::Plugin')->PluginList();

        # get working hour appointments
        my @WorkingHours = $Self->_GetWorkingHours();

        my $CurrentAppointment = 1;
        for my $Appointment (@WorkingHours) {

            # sort days of the week
            my @DoW = sort @{ $Appointment->{DoW} };

            # output block
            $LayoutObject->Block(
                Name => 'WorkingHours',
                Data => {
                    %{$Appointment},
                    DoW => $LayoutObject->JSONEncode( Data => \@DoW ),
                },
            );
            $LayoutObject->Block(
                Name => 'WorkingHoursComma',
            ) if $CurrentAppointment < scalar @WorkingHours;

            $CurrentAppointment++;
        }

        # auto open appointment
        $Param{AppointmentID} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam(
            Param => 'AppointmentID',
        ) // undef;
    }

    # show no calendar found message
    else {
        $LayoutObject->Block(
            Name => 'NoCalendar',
        );
    }

    # get text direction from language object
    my $TextDirection = $LayoutObject->{LanguageObject}->{TextDirection} || '';

    # output page
    my $Output = $LayoutObject->Header();
    $Output .= $LayoutObject->NavigationBar();
    $Output .= $LayoutObject->Output(
        TemplateFile => 'AgentAppointmentCalendarOverview',
        Data         => {
            EditAction        => 'AgentAppointmentEdit',
            EditMaskSubaction => 'EditMask',
            PrefSubaction     => 'UpdatePreferences',
            ListAction        => 'AgentAppointmentList',
            DaysSubaction     => 'AppointmentDays',
            FirstDay          => $Kernel::OM->Get('Kernel::Config')->Get('CalendarWeekDayStart') || 0,
            IsRTLLanguage     => ( $TextDirection eq 'rtl' ) ? 'true' : 'false',
            %Param,
        },
    );
    $Output .= $LayoutObject->Footer();
    return $Output;
}

sub _GetWorkingHours {
    my ( $Self, %Param ) = @_;

    # get working hours from sysconfig
    my $WorkingHoursConfig = $Kernel::OM->Get('Kernel::Config')->Get('TimeWorkingHours');

    # create working hour appointments for each day
    my @WorkingHours;
    for my $DayName ( sort keys %{$WorkingHoursConfig} ) {

        # day of the week
        my $DoW = 0;    # Sun
        if ( $DayName eq 'Mon' ) {
            $DoW = 1;
        }
        elsif ( $DayName eq 'Tue' ) {
            $DoW = 2;
        }
        elsif ( $DayName eq 'Wed' ) {
            $DoW = 3;
        }
        elsif ( $DayName eq 'Thu' ) {
            $DoW = 4;
        }
        elsif ( $DayName eq 'Fri' ) {
            $DoW = 5;
        }
        elsif ( $DayName eq 'Sat' ) {
            $DoW = 6;
        }

        my $StartTime = 0;
        my $EndTime   = 0;

        START_TIME:
        for ( $StartTime = 0; $StartTime < 24; $StartTime++ ) {

            # is this working hour?
            if ( grep { $_ eq $StartTime } @{ $WorkingHoursConfig->{$DayName} } ) {

                # go to the end of the working hours
                for ( my $EndHour = $StartTime; $EndHour < 24; $EndHour++ ) {
                    if ( !grep { $_ eq $EndHour } @{ $WorkingHoursConfig->{$DayName} } ) {
                        $EndTime = $EndHour;

                        # add appointment
                        if ( $EndTime > $StartTime ) {
                            push @WorkingHours, {
                                StartTime => sprintf( '%02d:00:00', $StartTime ),
                                EndTime   => sprintf( '%02d:00:00', $EndTime ),
                                DoW       => [$DoW],
                            };
                        }

                        # skip some hours
                        $StartTime = $EndHour;

                        next START_TIME;
                    }
                }
            }
        }
    }

    # collapse appointments with same start and end times
    for my $AppointmentA (@WorkingHours) {
        for my $AppointmentB (@WorkingHours) {
            if (
                $AppointmentA->{StartTime} && $AppointmentB->{StartTime}
                && $AppointmentA->{StartTime} eq $AppointmentB->{StartTime}
                && $AppointmentA->{EndTime} eq $AppointmentB->{EndTime}
                && $AppointmentA->{DoW} ne $AppointmentB->{DoW}
                )
            {
                push @{ $AppointmentA->{DoW} }, @{ $AppointmentB->{DoW} };
                $AppointmentB = undef;
            }
        }
    }

    # return only non-empty appointments
    return grep { scalar keys %{$_} } @WorkingHours;
}

1;
