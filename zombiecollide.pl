use strict;
use warnings;
use SDL;
use SDL::Rect;
use SDL::Events;
use Math::Trig;
use Collision::2D ':all';
use Data::Dumper;
use SDLx::App;
use SDLx::Controller::Object;
use SDLx::Sprite::Animated;

my $app = SDLx::App->new(
    w     => 640,
    h     => 480,
    dt    => 0.02, 
    fps   => 60, 
    title => 'Zombiecollide', 
    color => 0x00CC00FF,
);

$app->draw_rect(undef, 0x00CC00FF);
$app->update();

my @update_rects = ();

my $sprite = SDLx::Sprite->new(image => 'data/player.png');

my $obj = SDLx::Controller::Object->new(x => 140, y => 140, v_x => 0, v_y => 0);

my @collide_blocks;

my $pressed   = {};
my $vel_x     = 40;
my $vel_y     = -40;
my $quit      = 0;
my $dashboard = '';
my $w         = 30;
my $h         = 30;
my $scroller  = [0, 0];
my $scroll_v  = 2;
my $scroll_n  = 30;
my $bounce    = 15;

my $map = require("data/base.pl");

my $x = $w;
my $y = $h;
for (split(/\n/, $map->[0])) {
    for (/(.)/g) {
        if ($map->[1]->{$_}) {
            push(@collide_blocks, [$x, $y, $w, $h]);
        }
        $x += $w;
    }
    $y += $h;
    $x  = $w;
}

foreach (@collide_blocks) {
    $_->[4] = SDLx::Sprite->new(image => 'data/wall.png');
    $_->[4]->rect->centerx($_->[0]);
    $_->[4]->rect->centery($_->[1]);
}

$obj->set_acceleration(
    sub {
        my $time  = shift;
        my $state = shift;
        $state->v_x(0);    #Don't move by default
        $state->v_y(0); 
        my $ay = 0;

        if ($pressed->{'right shift'}) {
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

        my $w_ratio = 3;
        my $h_ratio = 3; # caine
        if ($state->v_x > $state->v_y) {
            $h_ratio = 1;
        } else {
            $w_ratio = 1;
        }
        my $c_rect = SDLx::Rect->new($state->x, $state->y, $w*3, $h*3);
        $c_rect->centerx($state->x);
        $c_rect->centery($state->y);
        # gather blocks colliding a rectangular area twice/thrice as big as the
        # player, and only check collision for those. checking every item in a
        # big map eats up lots of CPU time.
        my @check_blocks;
        foreach (@collide_blocks) {
            next unless ($c_rect->colliderect($_->[4]->rect));
            push(@check_blocks, $_);
        }
        my $collision = check_collision($state, \@check_blocks);
        $dashboard = 'Collision = ' . Dumper $collision;

        my $next_x = $state->x;
        my $next_y = $state->y;

        # x-axis collision check
        if ($collision != -1 && $collision->[0] eq 'x') {
            my $block = $collision->[1];
            $state->v_x(0);
            if ($state->v_x > 0) {      # moving right
                $next_x = $block->[0] - $block->[2]/2 - $bounce;
            } elsif ($state->v_x < 0) { # moving left
                $next_x = $block->[0] + $block->[2]/2 + $bounce;
            } else {                    # stopped at collision area
                if ($state->x > $block->[0]) {     # on the right side
                    $next_x = $block->[0] + $block->[2]/2 + $bounce;
                } elsif ($state->x < $block->[0]) { # on the left side
                    $next_x = $block->[0] - $block->[2]/2 - $bounce;
                }
            }
        }

        # y-axis collision check
        if ($collision != -1 && $collision->[0] eq 'y') {
            $state->v_y(0);
            my $block = $collision->[1];
            if ($state->v_y < 0) {     #moving up
                $next_y = $block->[1] + $block->[3]/2 + $bounce;
            } elsif ($state->v_y > 0) { # moving down
                $next_y = $block->[1] - $block->[3]/2 - $bounce;
            } else {                     # stopped at collision area
                if ($state->y < $block->[1]) {      # as above
                    $next_y = $block->[1] - $block->[3]/2 - $bounce;
                } elsif ($state->y > $block->[1]) { # so below
                    $next_y = $block->[1] + $block->[3]/2 + $bounce;
                }
            }
        }

        $state->x($next_x);
        $state->y($next_y);

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

            $_->[0] += $x foreach (@collide_blocks);
            $_->[1] += $y foreach (@collide_blocks);

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
            next if ($_->[0] < 0 or $_->[0] > $app->w);
            next if ($_->[1] < 0 or $_->[1] > $app->h);
            $_->[4]->rect->centerx($_->[0]);
            $_->[4]->rect->centery($_->[1]);
            $_->[4]->draw($app);
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
$app->add_show_handler(sub { $app->update(); });
$app->run_test;

sub check_collision_2 {
    my ($obj, $blocks) = @_;

    my $o_rect = SDLx::Rect->new($obj->x-$w/2, $obj->y-$h/2, $w, $h);
    foreach (@$blocks) {
        my $b_rect = $_->[4]->rect;
        my $c = $b_rect->colliderect_axis($o_rect);
        if ($c) {
            return [$c, $_];
        }
    }
    return -1;
}

sub check_collision {
    my ($object, $blocks) = @_;

    my @collisions = ();

    foreach (@$blocks) {
        my $hash = {
            x  => $object->x + 2.5,
            y  => $object->y + 2.5,
            w  => $w - 5,
            h  => $h - 5,
            xv => $object->v_x * 0.02,
            yv => $object->v_y * 0.02
        };
        my $rect  = hash2rect($hash);
        my $bhash = { x => $_->[0], y => $_->[1], w => $_->[2], h => $_->[3] };
        my $block = hash2rect($bhash);
        my $c =
          dynamic_collision($rect, $block, interval => 1, keep_order => 1);
        if ($c) {
            my $axis = $c->axis() || 'y';
            return [ $axis, $_ ];
        }
    }
    return -1;
}
