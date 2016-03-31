#!/usr/bin/perl
use strict;
use warnings;
use WWW::Google::Translate;
use DaZeus;

my %languages = (
	dutch => 'nl',
	english => 'en',
	french => 'fr',
	japanese => 'ja'
);

my ($socket, $key) = @ARGV;
if(!$socket || !$key) {
	warn "Usage: $0 <socket> <Google API translate key>\n";
	warn "For a translate key, visit: https://cloud.google.com/translate/docs\n";
	exit 1;
}

my $wgt = WWW::Google::Translate->new({key => $key});
# Uncomment this if your user-agent cannot establish trusted SSL connections, or give a SSL_ca_path
#$wgt->{ua}->ssl_opts(verify_hostname => 0);

my $dazeus = DaZeus->connect($socket) or die $!;

sub reply {
        my ($response, $network, $sender, $channel) = @_;

        if ($channel eq $dazeus->getNick($network)) {
                $dazeus->message($network, $sender, $response);
        } else {
                $dazeus->message($network, $channel, $response);
        }
}

$dazeus->subscribe_command("translate" => sub {
	my ($dazeus, $network, $sender, $channel, $command, $args) = @_;
	if(!$args || $args !~ /->/) {
		reply("Come on, give me something to do!", $network, $sender, $channel);
		return;
	}
	reply(translate_pipeline($args), $network, $sender, $channel);
});
while($dazeus->handleEvents()) {}

sub translate_pipeline {
	my ($pipeline) = @_;
	my $string;
	my @commands;

	if($pipeline =~ /^\s*"(.*)"\s+->\s+(.+)$/) {
		$string = $1;
		@commands = split /\s+->\s+/, $2;
	} else {
		@commands = split /\s+->\s+/, $pipeline;
		$string = shift @commands;
	}

	my $language;

	foreach my $command (@commands) {
		if($command =~ /^is(\w+)$/) {
			if(!exists $languages{lc $1}) {
				return "Sorry, I don't know the language '$1' :(\n";
			}
			$language = $languages{lc $1};
		} elsif($command =~ /^to(\w+)$/) {
			if(!exists $languages{lc $1}) {
				return "Sorry, I don't know the language '$1' :(\n";
			}
			my $to_language = $languages{lc $1};

			my $params = {
				q => $string,
				target => $to_language,
				format => 'text',
			};
			if($language) {
				if($language eq $to_language) {
					next;
				}
				$params->{'source'} = $language;
			}

			my $r = $wgt->translate($params);
			$string = $r->{'data'}{'translations'}[0]{'translatedText'};
			if(!$string) {
				return "Failed to translate from '$language' to '$to_language'!\n";
			}
			$language = $to_language;
		} else {
			return "I don't know what you meant by '$command' :(\n";
		}
	}

	return $string;
}