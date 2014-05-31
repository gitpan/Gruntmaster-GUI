package Gruntmaster::GUI;

use 5.014000;
use strict;
use warnings;
use parent qw/Wx::App/;
our $VERSION = '5999.000_001';
$VERSION = eval $VERSION;

use constant FORMATS => [qw/C CPP GO HASKELL JAVA PASCAL PERL PYTHON/];

use Gruntmaster::Data;
use Sub::Name qw/subname/;
use Try::Tiny;
use Wx qw/wxVERTICAL wxHORIZONTAL wxEXPAND wxALL wxTOP wxBOTTOM wxTE_MULTILINE wxTE_PROCESS_ENTER wxDefaultPosition wxDefaultSize wxLC_ICON/;
use Wx::Event qw/EVT_BUTTON EVT_COMBOBOX EVT_LISTBOX EVT_TEXT EVT_TEXT_ENTER/;

my ($db, $pb, $ct);
my ($problem_list, $contest_list, $job_list);
my (%problem, %contest);

sub problem_enable_relevant{
	$problem{genformat}->Enable($problem{generator}->GetValue eq 'Run');
	$problem{gensource}->Enable($problem{generator}->GetValue eq 'Run');
	$problem{verformat}->Enable($problem{runner}->GetValue ne 'File');
	$problem{versource}->Enable($problem{runner}->GetValue ne 'File');
	$problem{tests}->Enable($problem{runner}->GetValue eq 'File');
}

sub select_problem {
	my $id = $problem_list->GetClientData($problem_list->GetSelection);
	$pb = $db->problem($id);
	$problem{id}->SetLabel("ID: $id");
	$problem{$_}->SetValue($pb->get_column($_) // '') for qw/name author writer owner tests timeout olimit level generator runner judge testcnt value statement genformat gensource verformat versource/;
	$problem{private}->SetValue($pb->private);
	problem_enable_relevant;
}

sub select_contest {
	my $id = $contest_list->GetClientData($contest_list->GetSelection);
	$ct = $db->contest($id);
	$contest{id}->SetLabel("ID: $id");
	$contest{$_}->SetValue($ct->get_column($_)) for qw/name start stop owner/;
}

sub connect_or_disconnect {
	my ($dsn, $button, $nb) = @_;
	subname 'connect_or_disconnect', sub {
		if (defined $db) {
			undef $db;
			$dsn->Enable;
			$nb->Disable;
			$button->SetLabel('Connect');
			$problem_list->Clear;
		} else {
			try {
				$db = Gruntmaster::Data->connect($dsn->GetValue);
				$db->problems->count({}); # Trigger database connection
			} catch {
				Wx::MessageBox("Cannot connect to database: $_");
				undef $db;
			};
			return unless defined $db;
			$dsn->Disable;
			$nb->Enable;
			$button->SetLabel('Disconnect');
			$problem_list->Append($_->name, $_->id) for $db->problems->search({}, {order_by => 'name'});
			$problem_list->GetParent->GetSizer->Layout;
			$contest_list->Append($_->name, $_->id) for $db->contests->search({}, {order_by => 'name'});
			$contest_list->GetParent->GetSizer->Layout;
			$problem_list->SetSelection(0);
			$contest_list->SetSelection(0);
			select_problem;
			select_contest;
		}
		$button->GetParent->GetSizer->Layout;
	}
}

sub OnInit {
	my $frame = Wx::Frame->new(undef, -1, 'Gruntmaster 6000', [-1, -1], [500, 700]);
	my ($nb, $problems, $contests, $jobs);

	{
		my $panel = Wx::Panel->new($frame);
		my $subpanel = Wx::Panel->new($panel);
		my $panel_sizer = Wx::BoxSizer->new(wxVERTICAL);
		my $subpanel_sizer = Wx::BoxSizer->new(wxHORIZONTAL);

		my $dsn = Wx::TextCtrl->new($subpanel, -1, '', wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
		my $db_button = Wx::Button->new($subpanel, -1, 'Connect');
		$nb = Wx::Notebook->new($panel);
		$nb->Disable;
		EVT_BUTTON($db_button, $db_button, connect_or_disconnect $dsn, $db_button, $nb);
		EVT_TEXT_ENTER($dsn, $dsn, connect_or_disconnect $dsn, $db_button, $nb);

		$panel_sizer->Add($subpanel, 0, wxEXPAND | wxALL, 10);
		$panel_sizer->Add($nb, 1, wxEXPAND | wxALL, 10);
		$subpanel_sizer->Add($dsn, 1, wxEXPAND | wxALL, 10);
		$subpanel_sizer->Add($db_button, 0, wxEXPAND | wxALL, 10);
		$panel->SetSizer($panel_sizer);
		$subpanel->SetSizer($subpanel_sizer);
	}

	sub label {
		my ($parent, $sizer, $content) = @_;
		my $temp = Wx::StaticText->new($parent, -1, $content);
		$sizer->Add($temp, wxEXPAND);
		$temp
	}
	sub formsize {
		my ($sizer, $item) = @_;
		$sizer->Add($item, 0, wxEXPAND | wxTOP | wxBOTTOM, 5);
	}

	{
		$problems = Wx::Panel->new($nb);
		my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
		$problem_list = Wx::ListBox->new($problems);
		EVT_LISTBOX($problem_list, $problem_list, \&select_problem);
		my $form1 = Wx::ScrolledWindow->new($problems);
		my $form2 = Wx::ScrolledWindow->new($problems);
		my $f1sizer = Wx::BoxSizer->new(wxVERTICAL);
		my $f2sizer = Wx::BoxSizer->new(wxVERTICAL);
		$problem{id} = label $form1, $f1sizer, 'ID';
		my %id_to_label = (timeout => 'Time limit', olimit => 'Output limit');
		for (qw/name author writer owner tests timeout olimit/) {
			label $form1, $f1sizer, $id_to_label{$_} // ucfirst;
			formsize $f1sizer, $problem{$_} = Wx::TextCtrl->new($form1, -1, '');
		}
		$problem{private} = Wx::CheckBox->new($form2, -1, 'Private');
		$f2sizer->Add($problem{private});
		label $form2, $f2sizer, 'Level';
		formsize $f2sizer, $problem{level} = Wx::ComboBox->new($form2);
		$problem{level}->Append([qw/beginner easy medium hard/]);
		label $form2, $f2sizer, 'Generator';
		formsize $f2sizer, $problem{generator} = Wx::ComboBox->new($form2);
		$problem{generator}->Append([qw/File Run Undef/]);
		label $form2, $f2sizer, 'Runner';
		formsize $f2sizer, $problem{runner} = Wx::ComboBox->new($form2);
		$problem{runner}->Append([qw/File Verifier Interactive/]);
		label $form2, $f2sizer, 'Judge';
		formsize $f2sizer, $problem{judge} = Wx::ComboBox->new($form2);
		$problem{judge}->Append([qw/Absolute Points/]);
		label $form2, $f2sizer, 'Test count';
		formsize $f2sizer, $problem{testcnt} = Wx::SpinCtrl->new($form2);
		label $form2, $f2sizer, 'Value';
		formsize $f2sizer, $problem{value} = Wx::SpinCtrl->new($form2);
		label $form1, $f1sizer, 'Statement';
		formsize $f1sizer, $problem{statement} = Wx::TextCtrl->new($form1, -1, '', wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE);
		#$f1sizer->Add($problem{statement}, 2, wxEXPAND | wxTOP | wxBOTTOM, 5);
		label $form2, $f2sizer, 'Generator program';
		formsize $f2sizer, $problem{genformat} = Wx::ComboBox->new($form2);
		$problem{genformat}->Append(FORMATS);
		formsize $f2sizer, $problem{gensource} = Wx::TextCtrl->new($form2, -1, '', wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE);
		label $form2, $f2sizer, 'Verifier program';
		formsize $f2sizer, $problem{verformat} = Wx::ComboBox->new($form2);
		$problem{verformat}->Append(FORMATS);
		formsize $f2sizer, $problem{versource} = Wx::TextCtrl->new($form2, -1, '', wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE);
		EVT_COMBOBOX($problem{$_}, $problem{$_}, \&problem_enable_relevant) for qw/generator runner/;
		EVT_TEXT($problem{$_}, $problem{$_}, \&problem_enable_relevant) for qw/generator runner/;

		$sizer->Add($problem_list, 0, wxEXPAND | wxALL, 10);
		$sizer->Add($form1, 1, wxALL, 10);
		$sizer->Add($form2, 1, wxALL, 10);
		$form1->SetSizer($f1sizer);
		$form2->SetSizer($f2sizer);
		$problems->SetSizer($sizer);
	}

	{
		$contests = Wx::Panel->new($nb);
		my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
		$contest_list = Wx::ListBox->new($contests);
		EVT_LISTBOX($contest_list, $contest_list, \&select_contest);
		my $form = Wx::ScrolledWindow->new($contests);
		my $fsizer = Wx::BoxSizer->new(wxVERTICAL);
		$contest{id} = label $form, $fsizer, 'ID';
		label $form, $fsizer, 'Name';
		formsize $fsizer, $contest{name} = Wx::TextCtrl->new($form, -1, '');
		label $form, $fsizer, 'Start';
		formsize $fsizer, $contest{start} = Wx::TextCtrl->new($form, -1, '');
		label $form, $fsizer, 'Stop';
		formsize $fsizer, $contest{stop} = Wx::TextCtrl->new($form, -1, '');
		label $form, $fsizer, 'owner';
		formsize $fsizer, $contest{owner} = Wx::TextCtrl->new($form, -1, '');

		$sizer->Add($contest_list, 0, wxEXPAND | wxALL, 10);
		$sizer->Add($form, 1, wxALL, 10);
		$form->SetSizer($fsizer);
		$contests->SetSizer($sizer);
	}

	$nb->AddPage($problems, 'Problems');
	$nb->AddPage($contests, 'Contests');
	$frame->Show(1)
}

1;
__END__

=head1 NAME

Gruntmaster::GUI - Gruntmaster 6000 Online Judge -- GUI database editor

=head1 SYNOPSIS

  use Gruntmaster::GUI;
  Gruntmaster::GUI->new->MainLoop;

=head1 DESCRIPTION

Gruntmaster::GUI is a GUI viewer and editor for the Gruntmaster 6000 database.

CLI tools with the same purpose are distributed with Gruntmaster::Data. See L<gruntmaster-contest(1)>, L<gruntmaster-job(1)>, L<gruntmaster-problem(1)>.

=head1 AUTHOR

Marius Gavrilescu E<lt>marius@ieval.roE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Marius Gavrilescu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.18.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
