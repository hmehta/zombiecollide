use strict;
use warnings;
use SDL;
use SDL::Rect;
use SDL::Events;
use Math::Trig;
use Collision::Util qw/check_collision_interval/;
use Data::Dumper;
use SDLx::App;
use SDLx::Controller::Object;
use SDLx::Sprite;
use Block; # a wrapper class to fit SDLx::Controller::State into Collision::Util ;<

my $app = SDLx::App->new(
    w     => 640,
    h     => 480,
    dt    => 0.02, 
    title => 'Zombiecollide', 
    color => 0x00CC00FF,
);

$app->draw_rect(undef, 0x00CC00FF);
$app->update();

my @update_rects = ();

my $sprite = SDLx::Sprite->new(image => 'data/player.png');
my $othersprite = SDLx::Sprite->new(image => 'data/ball.png');
my $obj = SDLx::Controller::Object->new(x => 90, y => 90, v_x => 0, v_y => 0);
my $eobj = SDLx::Controller::Object->new(x => 350, y => 350, v_x => 0, v_y => 0);

my @collide_blocks;

my $pressed   = {};
my $vel_x     = 40;
my $vel_y     = -40;
my $quit      = 0;
my $w         = 25;
my $h         = 25;
my $scroller  = [0, 0];
my $scroll_v  = 2;
my $scroll_n  = 30;
my $bounce    = 80;

my $map = require("data/base.pl");

my $x = $w;
my $y = $h;
for (split(/\n/, $map->[0])) {
    for (/(.)/g) {
        if ($map->[1]->{$_}) {
            push(@collide_blocks, [Block->new(x => $x, y => $y, w => $w, h => $h), SDLx::Sprite->new(image => 'data/wall.png')]);
        }
        $x += $w;
    }
    $y += $h;
    $x  = $w;
}

foreach (@collide_blocks) {
    $_->[1]->rect->centerx($_->[0]->x);
    $_->[1]->rect->centery($_->[0]->y);
}
$eobj->set_acceleration(
    sub {
        my ($time, $state) = @_;
#        my $angle = rad2deg(atan2($sprite->rect->centerx - $state->x, $sprite->rect->centery - $state->y));
#        $state->v_x(40*sin($angle));
#        $state->v_y(40*cos($angle));
#        collision_check($state);
        return (0, 0, 0);
    }
);
$obj->set_acceleration(
    sub {
        my ($time, $state) = @_;
        $state->v_x(0);    # don't move by default
        $state->v_y(0); 
        my $ay = 0;

        if ($pressed->{'left shift'}) {
            $vel_x =  80;
            $vel_y = -80;
        } else {
            $vel_x =  40;
            $vel_y = -40;
        }
        #Basic movements
        if ($pressed->{d}) {
            $state->v_x($vel_x);
        }
        if ($pressed->{a}) {
            $state->v_x(-$vel_x);
        }
        if ($pressed->{w}) {
            $state->v_y($vel_y);
        }
        if ($pressed->{s}) {
            $state->v_y(-$vel_y);
        }

        $state = collision_check($state);

        if ($pressed->{escape}) {
            $quit = 1;
        }

        if ($scroller->[0] or $scroller->[1]) {
            my ($x, $y);
            $x = $y = 0;
            if ($scroller->[0] > 0) {
                $scroller->[0]--;
                $x = $scroll_v;
            } elsif ($scroller->[0] < 0) {
                $scroller->[0]++;
                $x = -$scroll_v;
            }
            if ($scroller->[1] > 0) {
                $y = -$scroll_v;
                $scroller->[1]--;
            } elsif ($scroller->[1] < 0) {
                $y = $scroll_v;
                $scroller->[1]++;
            }
            $state->x($state->x + $x);
            $state->y($state->y + $y);

            $_->[0]->{x} = $_->[0]->x + $x foreach (@collide_blocks);
            $_->[0]->{y} = $_->[0]->y + $y foreach (@collide_blocks);

        } else {
            if ($state->x > $app->w - 100) {
                $scroller->[0] = -$scroll_n;
            }
            if ($state->x < 100) {
                $scroller->[0] = $scroll_n;
            }
            if ($state->y > $app->h - 100) {
                $scroller->[1] = $scroll_n;
            }
            if ($state->y < 100) {
                $scroller->[1] = -$scroll_n;
            }
        }

        return (0, $ay, 0);
    }
);

my $render_obj = sub {
    my $state = shift;

#    my $c_rect = SDLx::Rect->new($state->x, $state->y, $w*2, $h*2);
#    $c_rect->centerx($state->x);
#    $c_rect->centery($state->y);
#    $app->draw_rect($c_rect, 0xFF00CCFF);

    my $m = SDL::Events::get_mouse_state();
    $sprite->rotation(rad2deg(atan2($m->[1] - $sprite->rect->x, $m->[2] - $sprite->rect->y)));    
    $sprite->rect->centerx($state->x);
    $sprite->rect->centery($state->y);
    $sprite->draw($app);
};

my $render_eobj = sub {
    my ($state) = @_;
    $othersprite->rect->centerx($state->x);
    $othersprite->rect->centery($state->y);
    $othersprite->draw($app);
};

$app->add_event_handler(
    sub {
        return 0 if $_[0]->type == SDL_QUIT;

        my $key = $_[0]->key_sym;
        my $name = SDL::Events::get_key_name($key) if $key;

        if ($_[0]->type == SDL_KEYDOWN) {
            $pressed->{$name} = 1;
        }
        elsif ($_[0]->type == SDL_KEYUP) {
            $pressed->{$name} = 0;
        }

        return 1 if !$quit;
    }
);

$app->add_show_handler(
    sub {
    $app->draw_rect([ 0, 0, $app->w, $app->h ], 0x00CC00);
#        $app->draw_rect($_, 0xFFFF0000) foreach @collide_blocks;
        foreach (@collide_blocks) {
            $_->[1]->rect->centerx($_->[0]->x);
            $_->[1]->rect->centery($_->[0]->y);
            $_->[1]->draw($app);
        }
        SDL::GFX::Primitives::string_color(
            $app,
            $app->w / 2 - 100,
            $app->h / 2,
            "quitted", 0xFF0000FF
        ) if $quit;
    }
);

$app->add_object($obj, $render_obj);
#$app->add_object($eobj, $render_eobj);
$app->add_show_handler(sub { $app->update(); });
$app->run_test;

sub collision_check {
    my ($state) = @_;
    my $c_rect = SDLx::Rect->new($state->x, $state->y, $w*1.5, $h*1.5);
    $c_rect->centerx($state->x);
    $c_rect->centery($state->y);
    # gather blocks colliding a rectangular area a bit bigger as the
    # player, and only check collision for those. checking every item in a
    # big map eats up lots of CPU time.
    my @check_blocks;
    foreach (@collide_blocks) {
        next unless ($c_rect->colliderect($_->[1]->rect));
        push(@check_blocks, $_);
    }
    my $b = Block->new(x => $state->x, y => $state->y, w => $w, h => $h, v_x => $state->v_x*0.02, v_y => $state->v_y*0.02);
    @check_blocks = map { $_->[0] } @check_blocks;
    my @collisions = check_collision_interval($b, \@check_blocks, 1);
#        print "collisions: ", Dumper @collisions, "\n" unless ($collisions[0]->[0] == -1);

    foreach my $collision (@collisions) {
        # x-axis collision check
        if ($collision->[0] != -1 && $collision->[1]->[0] != 0) {
            my $block = $check_blocks[$collision->[0]];
            my $v_cur = $state->v_x;
            if ($state->v_x > 0) {      # moving right
                $state->v_x(-$bounce) if ($collision->[1]->[0] == -1);
            } elsif ($state->v_x < 0) { # moving left
                $state->v_x($bounce) if ($collision->[1]->[0] == 1);
            }
        }

        # y-axis collision check (only collide on one axis!)
        if ($collision->[0] != -1 && $collision->[1]->[1] != 0) {
            my $block = $check_blocks[$collision->[0]];            
            my $v_cur = $state->v_y;
            if ($state->v_y < 0) {     #moving up
                $state->v_y($bounce) if ($collision->[1]->[1] == -1);                    
            } elsif ($state->v_y > 0) { # moving down
                $state->v_y(-$bounce) if ($collision->[1]->[1] == 1);
            }
        }
    }
    return $state;
}
