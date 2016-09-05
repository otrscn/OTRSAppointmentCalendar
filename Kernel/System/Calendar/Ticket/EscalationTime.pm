# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Calendar::Ticket::EscalationTime;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

=head1 NAME

Kernel::System::Calendar::Ticket::EscalationTime - EscalationTime appointment type

=head1 SYNOPSIS

EscalationTime ticket appointment type.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TicketEscalationTimeObject = $Kernel::OM->Get('Kernel::System::Calendar::Ticket::EscalationTime');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item GetTime()

returns time value for escalation time appointment type.

    my $SolutionTime = $TicketEscalationTimeObject->GetTime(
        Type     => 'SolutionTime',
        TicketID => 1,
    );

=cut

sub GetTime {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Type TicketID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get ticket data
    my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
        TicketID => $Param{TicketID},
    );
    return if !$Ticket{ $Param{Type} . 'DestinationDate' };

    # return escalation destination date
    return $Ticket{ $Param{Type} . 'DestinationDate' };
}

=item SetTime()

does nothing, as you cannot explicitly set ticket escalation times.
returns 1 to prevent errors in log.

=cut

sub SetTime {
    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut