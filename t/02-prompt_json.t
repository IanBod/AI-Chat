#!perl
use strict;
use warnings;
use Test::More;
use JSON::PP;
use Encode qw(encode_utf8);

use AI::Chat;

# Mocking HTTP::Tiny::post
my $mock_response;
{
    no warnings 'redefine';
    *HTTP::Tiny::post = sub {
        return $mock_response;
    };
}

my $chat = AI::Chat->new(
    key   => 'test-key',
    api   => 'OpenAI',
);

subtest 'Parameter Validation' => sub {
    my $res = $chat->prompt_json("");
    ok(!$res, 'Empty prompt returns undef');
    is($chat->error, "Missing prompt calling 'prompt_json' method", 'Correct error message');
};

subtest 'Successful JSON Response' => sub {
    my $expected_data = { result => 'success', value => 42 };
    my $inner_json = encode_json($expected_data);
    
    $mock_response = {
        success => 1,
        content => encode_json({
            choices => [
                {
                    message => {
                        content => $inner_json,
                    }
                }
            ]
        })
    };

    my $data = $chat->prompt_json("Give me some JSON");
    ok($chat->success, 'Operation successful');
    is_deeply($data, $expected_data, 'Correctly decoded JSON returned');
};

subtest 'Invalid JSON from LLM' => sub {
    $mock_response = {
        success => 1,
        content => encode_json({
            choices => [
                {
                    message => {
                        content => "This is not JSON",
                    }
                }
            ]
        })
    };

    my $data = $chat->prompt_json("Give me some JSON");
    ok(!$data, 'Invalid JSON returns undef');
    like($chat->error, qr/Invalid JSON returned/, 'Error message contains expected text');
};

subtest 'API Error' => sub {
    $mock_response = {
        success => 0,
        content => '{"error": {"message": "Invalid API Key"}}',
    };

    my $data = $chat->prompt_json("Give me some JSON");
    ok(!$data, 'API error returns undef');
    is($chat->error, $mock_response->{content}, 'Error message matches API content');
};

done_testing();
