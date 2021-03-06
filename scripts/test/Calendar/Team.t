# --
# Copyright (C) 2001-2016 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $TeamObject   = $Kernel::OM->Get('Kernel::System::Calendar::Team');
my $GroupObject  = $Kernel::OM->Get('Kernel::System::Group');
my $UserObject   = $Kernel::OM->Get('Kernel::System::User');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# create test user
my $UserLogin = $Helper->TestUserCreate();
my $UserID = $UserObject->UserLookup( UserLogin => $UserLogin );

$Self->True(
    $UserID,
    "Test user $UserID created",
);

# create test group
my $GroupName = 'test-calendar-group-' . $Helper->GetRandomID();
my $GroupID   = $GroupObject->GroupAdd(
    Name    => $GroupName,
    ValidID => 1,
    UserID  => 1,
);

$Self->True(
    $GroupID,
    "Test group $GroupID created",
);

# add test user to test group
my $Success = $GroupObject->PermissionGroupUserAdd(
    GID        => $GroupID,
    UID        => $UserID,
    Permission => {
        ro        => 1,
        move_into => 1,
        create    => 1,
        owner     => 1,
        priority  => 1,
        rw        => 1,
    },
    UserID => 1,
);

$Self->True(
    $Success,
    "Test user $UserID added to test group $GroupID",
);

$Success = $TeamObject->TeamAdd(
    Name    => 'Test Team',
    GroupID => 1,              # admin
    Comment => 'My comment',
    ValidID => 1,
    UserID  => $UserID,
);

$Self->True(
    $Success,
    'TeamAdd - team successfully created',
);

my %List = $TeamObject->TeamList(
    Valid  => 1,
    UserID => $UserID,
);

$Self->Is(
    scalar keys %List,
    1,
    'TeamList - one team found',
);

my $TeamID;

TEAM_ID:
for my $ListTeamID ( sort keys %List ) {

    $TeamID = $ListTeamID;

    my %Team = $TeamObject->TeamGet(
        TeamID => $TeamID,
        UserID => $UserID,
    );

    $Self->Is(
        $Team{ID},
        $TeamID,
        'TeamGet - ID OK',
    );

    $Self->Is(
        $Team{Name},
        'Test Team',
        'TeamGet - Name OK',
    );

    $Self->Is(
        $Team{GroupID},
        1,
        'TeamGet - GroupID OK',
    );

    $Self->Is(
        $Team{Comment},
        'My comment',
        'TeamGet - Comment OK',
    );

    $Self->Is(
        $Team{ValidID},
        1,
        'TeamGet - ValidID OK',
    );

    $Self->Is(
        $Team{CreateBy},
        $UserID,
        'TeamGet - CreateBy OK',
    );

    $Self->Is(
        $Team{ChangeBy},
        $UserID,
        'TeamGet - ChangeBy OK',
    );

    last TEAM_ID;
}

$Success = $TeamObject->TeamAdd(
    GroupID => $GroupID,
    Comment => 'My comment',
    ValidID => 1,
    UserID  => $UserID,
);

$Self->False(
    $Success,
    'TeamAdd - no team name',
);

$Success = $TeamObject->TeamAdd(
    Name    => 'Test Team 2',
    GroupID => $GroupID,
    Comment => 'My comment',
    ValidID => 1,
);

$Self->False(
    $Success,
    'TeamAdd - no user ID',
);

$Success = $TeamObject->TeamAdd(
    Name    => 'Test Team 2',
    Comment => 'My comment',
    ValidID => 1,
    UserID  => $UserID,
);

$Self->False(
    $Success,
    'TeamAdd - no group ID',
);

$Success = $TeamObject->TeamAdd(
    Name    => 'Test Team 2',
    Comment => 'My comment',
    GroupID => $GroupID,
    UserID  => $UserID,
);

$Self->False(
    $Success,
    'TeamAdd - no valid ID',
);

$Success = $TeamObject->TeamAdd(
    Name    => 'The Dream Team',
    GroupID => -1,
    Comment => 'Team from dreams',
    ValidID => 1,
    UserID  => $UserID,
);

$Self->False(
    $Success,
    'TeamAdd - non-existing group',
);

$Success = $TeamObject->TeamAdd(
    Name    => 'Test Team',
    GroupID => 1,
    Comment => 'My comment',
    ValidID => 1,
    UserID  => $UserID,
);

$Self->False(
    $Success,
    'TeamAdd - same name',
);

# change the team
$Success = $TeamObject->TeamUpdate(
    TeamID  => $TeamID,
    Name    => 'New Name',
    GroupID => $GroupID,
    Comment => 'Some comment',
    ValidID => 1,
    UserID  => $UserID,
);

$Self->True(
    $Success,
    'TeamUpdate - team changed',
);

my %Team = $TeamObject->TeamGet(
    TeamID => $TeamID,
    UserID => $UserID,
);

$Self->Is(
    $Team{Name},
    'New Name',
    'TeamGet - team name changed',
);

$Self->Is(
    $Team{GroupID},
    $GroupID,
    'TeamGet - team group ID changed',
);

$Self->Is(
    $Team{Comment},
    'Some comment',
    'TeamGet - team comment changed',
);

$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# create test user
my $TestUserLogin = $Helper->TestUserCreate();
my $TestUserID = $UserObject->UserLookup( UserLogin => $TestUserLogin );

# check permissions
%List = $TeamObject->AllowedTeamList(
    UserID => $TestUserID,
);

$Self->Is(
    scalar keys %List,
    0,
    'AllowedTeamList() - test user has no permissions',
);

# grant permissions
$Success = $GroupObject->PermissionGroupUserAdd(
    GID        => $GroupID,
    UID        => $TestUserID,
    Permission => {
        ro        => 1,
        move_into => 1,
        create    => 1,
        owner     => 1,
        priority  => 1,
        rw        => 1,
    },
    UserID => $UserID,
);

$Self->True(
    $Success,
    'PermissionGroupUserAdd() - test user granted permissions',
);

# check permissions again
%List = $TeamObject->AllowedTeamList(
    UserID => $TestUserID,
);

$Self->Is(
    scalar keys %List,
    1,
    'AllowedTeamList() - test user allowed on one team',
);

$Success = $TeamObject->TeamUserAdd(
    TeamID     => $TeamID,
    TeamUserID => $TestUserID,
    UserID     => $UserID,
);

$Self->True(
    $Success,
    'TeamUserAdd() - add test user to the team',
);

%List = $TeamObject->TeamUserList(
    TeamID => $TeamID,
    UserID => $UserID,
);

my $Found = scalar grep { $_ eq $TestUserID } keys %List;

$Self->Is(
    $Found,
    1,
    'TeamUserList() - test user added to the team',
);

$Success = $TeamObject->TeamUserRemove(
    TeamID     => $TeamID,
    TeamUserID => $TestUserID,
    UserID     => $UserID,
);

$Self->True(
    $Success,
    'TeamUserAdd() - remove test user from the team',
);

%List = $TeamObject->TeamUserList(
    TeamID => $TeamID,
    UserID => $UserID,
);

$Found = scalar grep { $_ eq $TestUserID } keys %List;

$Self->Is(
    $Found,
    0,
    'TeamUserList() - test user removed from the team',
);

1;
