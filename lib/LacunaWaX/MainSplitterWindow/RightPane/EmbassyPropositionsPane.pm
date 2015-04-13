

### SEARCH ON 'CHECK'
###
###
###


=head2 CHILD WINDOWS

Each prop displayed in the EmbassyPropositionsPane is its own PropRow object.  Each of 
these rows creates its own Dialog::Status object which will display status of 
sitter voting on that particular prop.

So creation and destruction of the Dialog::Status windows is the responsibility of 
the individual PropRow objects; see PropRow.pm for that.

Self-voting does not display a Dialog::Status as it's not necessary.

=cut

package LacunaWaX::MainSplitterWindow::RightPane::EmbassyPropositionsPane {
    use v5.14;
    use LacunaWaX::Model::Client;
    use Moose;
    use Try::Tiny;
    use Wx qw(:everything);
    with 'LacunaWaX::Roles::MainSplitterWindow::RightPane';

    use LacunaWaX::MainSplitterWindow::RightPane::EmbassyPropositionsPane::PropRow;

    has 'parent' => (
        is          => 'rw',
        isa         => 'Wx::ScrolledWindow',
        required    => 1,
    );

    #########################################

    has 'emb'   => (is => 'rw', isa => 'Maybe[Games::Lacuna::Client::Buildings::Embassy]',  lazy_build => 1);
    has 'props' => (is => 'rw', isa => 'ArrayRef',                                          lazy_build => 1);

    has 'rows' => (is => 'rw', isa => 'ArrayRef', lazy => 1, default => sub{ [] });

    has 'already_voted' => (is => 'rw', isa => 'HashRef', lazy => 1, default => sub{ {} },
        clearer => 'clear_already_voted',
        documentation => q/
            If a user has already voted on one prop, they've probably already voted on all of them.
            Players who've already voted on something get put in here.
            { player_name => their record in the SitterPasswords table. }
        /
    );
    has 'over_rpc' => (is => 'rw', isa => 'HashRef', lazy => 1, default => sub{ {} },
        documentation => q{
            Players who are over their daily RPC usage get put in here (by name) so we don't try 
            voting for them again (no point).
        }
    );

    has 'row_spacer_size' => (is => 'rw', isa => 'Int', lazy => 1, default => 1,
        documentation => q{
            The pixel size of the horizontal spacer used to slightly separate each row
        }
    );

    has 'szr_header'               => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'vertical'     );
    has 'szr_props'                => (is => 'rw', isa => 'Wx::Sizer',                          documentation => 'vertical'     );
    has 'szr_close_status'         => (is => 'rw', isa => 'Wx::Sizer',         lazy_build => 1, documentation => 'horizontal'   );

    has 'lbl_header'                => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_instructions_box'      => (is => 'rw', isa => 'Wx::BoxSizer',      lazy_build => 1);
    has 'lbl_instructions'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'lbl_close_status'          => (is => 'rw', isa => 'Wx::StaticText',    lazy_build => 1);
    has 'chk_close_status'          => (is => 'rw', isa => 'Wx::CheckBox',      lazy_build => 1);

    sub BUILD {
        my $self = shift;

        return unless $self->emb_exists_here;

        wxTheApp->borders_off();    # Change to borders_on to see borders around sizers

        $self->szr_header->Add($self->lbl_header, 0, 0, 0);
        $self->szr_header->AddSpacer(5);
        $self->szr_header->Add($self->lbl_instructions_box, 0, 0, 0);

        $self->szr_close_status->Add($self->lbl_close_status, 0, 0, 0);
        $self->szr_close_status->AddSpacer(10);
        $self->szr_close_status->Add($self->chk_close_status, 0, 0, 0);

        $self->szr_props( $self->create_szr_props() );

        $self->content_sizer->Add($self->szr_header, 0, 0, 0);
        $self->content_sizer->Add($self->szr_close_status, 0, 0, 0);
        $self->content_sizer->AddSpacer(20);
        $self->content_sizer->Add($self->szr_props, 0, 0, 0);

        $self->_set_events();
        return $self;
    }
    sub _build_emb {#{{{
        my $self = shift;

        my $c = wxTheApp->game_client();
        my $emb = $c->client->building(id => $c->primary_embassy_id, type => 'embassy');

        return( $emb and ref $emb eq 'Games::Lacuna::Client::Buildings::Embassy' ) ? $emb : undef;
    }#}}}
    sub _build_props {#{{{
        my $self = shift;
        my $props = [];
        return $props unless $self->emb_exists_here;

        $props = try {
            my $rv = $self->emb->view_propositions();
            return $rv->{'propositions'} // $props;
        }
        catch {
            my $msg = (ref $_) ? $_->text : $_;
            wxTheApp->poperr($msg);
            return $props;
        };

        return $props;
    }#}}}
    sub _build_lbl_close_status {#{{{
        my $self = shift;

        my $text = "Close the sitter status window automatically?";

        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, -1)
        );
        $v->SetFont( wxTheApp->get_font('para_text_2') );

        return $v;
    }#}}}
    sub _build_lbl_instructions {#{{{
        my $self = shift;

        my $text = "    Mouse over a proposition's name to get its full description.  If nothing is listed below, there are simply no propositions active right now.
    If you click the 'Yes' button under 'Sitters:', a Yes vote will be recorded for every player for whom you have recorded a sitter password (provided that player is in your alliance).";
    #There is not a 'No:' button under Sitters on purpose.  This is because I'm having a hard time envisioning a circumstance where you'd need to explicitly vote No for all of the people you have sitters for.  I think it's much more likely that such a button would get clicked by accident at some point.  And once a vote has been cast, it can't be changed.  So being able to vote No for all of your sitters just seems fraught with danger.  Yeah, I said 'fraught'.";

        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            $text,
            wxDefaultPosition, 
            Wx::Size->new(-1, 90)
        );
        $v->SetFont( wxTheApp->get_font('para_text_2') );
        $v->Wrap(550);

        return $v;
    }#}}}
    sub _build_lbl_instructions_box {#{{{
        my $self = shift;
        my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
        $sizer->Add($self->lbl_instructions, 0, 0, 0);
        return $sizer;
    }#}}}
    sub _build_lbl_header {#{{{
        my $self = shift;

        my $v = Wx::StaticText->new(
            $self->parent, -1, 
            "All Propositions",
            wxDefaultPosition, 
            Wx::Size->new(-1, 30)
        );
        $v->SetFont( wxTheApp->get_font('header_1') );
        return $v;
    }#}}}
    sub _build_chk_close_status {#{{{
        my $self = shift;
        my $v = Wx::CheckBox->new(
            $self->parent, -1, 
            'Yes',
            wxDefaultPosition, 
            Wx::Size->new(-1,-1), 
        );
        $v->SetFont( wxTheApp->get_font('para_text_2') );
        return $v;
    }#}}}
    sub _build_szr_header {#{{{
        my $self = shift;
        return wxTheApp->build_sizer($self->parent, wxVERTICAL, 'Header');
    }#}}}
    sub _build_szr_close_status {#{{{
        my $self = shift;
        return wxTheApp->build_sizer($self->parent, wxHORIZONTAL, 'Close Status Window?', 0);
    }#}}}
    sub _set_events { }

    sub create_szr_props {#{{{
        my $self = shift;

        my $szr_props = wxTheApp->build_sizer($self->parent, wxVERTICAL, 'Props');

        my $header = LacunaWaX::MainSplitterWindow::RightPane::EmbassyPropositionsPane::PropRow->new(
            ancestor    => $self,
            parent      => $self->parent,
            is_header   => 1,
        );
        $szr_props->Add($header->main_sizer, 0, 0, 0);

        foreach my $prop( @{$self->props} ) {
            my $row = LacunaWaX::MainSplitterWindow::RightPane::EmbassyPropositionsPane::PropRow->new(
                ancestor    => $self,
                parent      => $self->parent,
                emb         => $self->emb,
                prop        => $prop,
            );
            push @{$self->rows}, $row;
            $szr_props->Add( $row->main_sizer, 0, 0, 0 );
            $szr_props->AddSpacer( $self->row_spacer_size );
            wxTheApp->Yield;
        }

        $szr_props->AddSpacer( $self->row_spacer_size * 10 );

        if( @{ $self->rows } ) {
            my $footer = LacunaWaX::MainSplitterWindow::RightPane::EmbassyPropositionsPane::PropRow->new(
                app         => wxTheApp,
                ancestor    => $self,
                parent      => $self->parent,
                rows        => $self->rows,
                is_footer   => 1,
            );
            $szr_props->Add($footer->main_sizer, 0, 0, 0);
        }

        return $szr_props;
    }#}}}
    sub emb_exists_here {#{{{
        my $self = shift;

        ### Calls emb's lazy builder if needed, which returns undef if no emb
        return $self->emb;
    };#}}}

    sub OnClose {#{{{
        my $self    = shift;

        foreach my $row( @{$self->rows} ) {
            $row->OnClose if $row->can('OnClose');
        }
        return 1;
    }#}}}

    no Moose;
    __PACKAGE__->meta->make_immutable; 
}

1;
