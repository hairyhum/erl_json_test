-module(erl_json_test).
-export([start/0]).
-define(RESULTS_FILE, "results.csv").
-define(NUM_TESTS, 100).
-define(PARSERS,
        [
        % {"jsonx", fun jsonx:encode/1, fun(Data) -> {map, M} = jsonx:decode(Data, [{format, map}]), M end},
         % {"yawsjson2", fun json2:encode/1, fun json2:decode/1},
         {"jiffy", fun jiffy:encode/1, fun(Data) -> jiffy:decode(Data, [return_maps]) end},
         % {"jsonerl", fun jsonerl:encode/1, fun jsonerl:decode/1},
         {"mochijson2", fun(Enc) -> iolist_to_binary(mochijson2:encode(Enc)) end, fun(Data) -> mochijson2:decode(Data) end},
         {"jsx", fun jsx:encode/1, fun(D) -> jsx:decode(D, [return_maps]) end},
         {"jsone", fun jsone:encode/1, fun jsone:decode/1}]).
-define(TESTFILES,
        [
         % {"1x", "1x.json"},
         % {"3x", "3x.json"},
         % {"9x", "9x.json"},
         % {"27x", "27x.json"},
         % {"81x", "81x.json"},
         % {"243x", "243x.json"},
         {"queues", "queues.json"},

         {"channels", "channels.json"},
         {"connections", "connections.json"}
         ]).

start() ->
    JSONs = [begin
                 FullName = "priv/" ++ FileName,
                 {ok, File} = file:read_file(FullName),
                 {Name, File}
             end
             || {Name, FileName} <- ?TESTFILES],
    _A = [ jsonx:encode(jsonx:decode(File)) || {_, File} <- JSONs],
    _B = [ jiffy:encode(jiffy:decode(File, [return_maps])) || {_, File} <- JSONs],
    _C = [ iolist_to_binary(mochijson2:encode(mochijson2:decode(File))) || {_, File} <- JSONs],
    _D = [ jsx:encode(jsx:decode(File, [return_maps])) || {_, File} <- JSONs],
    _E = [ jsone:encode(jsone:decode(File)) || {_, File} <- JSONs],
    ResultsDeep = [[begin
                        T = {ParserName, TestName, size(JSON),
                             bench(EncFun, DecFun, JSON)},
                        io:format("~s ~s done~n", [ParserName, TestName]),
                        T
                    end
                    || {TestName, JSON} <- JSONs]
                   || {ParserName, EncFun, DecFun} <- ?PARSERS],
    Results = lists:flatten(ResultsDeep),
    format_results(Results),
    init:stop().

bench(EncFun, DecFun, TestJSON) ->
    DecThunk = fun() -> times(DecFun, TestJSON, ?NUM_TESTS) end,
    {DecTime, Decoded} = timer:tc(DecThunk),
    EncThunk = fun() -> times(EncFun, Decoded, ?NUM_TESTS) end,
    {EncTime, _} = timer:tc(EncThunk),
    {EncTime, DecTime}.

format_results(Results) ->
    Header = io_lib:format("\"Parser\","
                           "\"Test\","
                           "\"TestSize\","
                           "\"ResultEnc\","
                           "\"ResultDec\"~n", []),
    Out = [Header |
           [io_lib:format("\"~s\",\"~s (~pb)\",~p,~p,~p~n",
                          [Parser, Test, TestSize, TestSize,
                           round(ResultEnc / ?NUM_TESTS),
                           round(ResultDec / ?NUM_TESTS)])
            || {Parser, Test, TestSize, {ResultEnc, ResultDec}} <- Results]],
    file:write_file(?RESULTS_FILE, lists:flatten(Out)).

times(F, X,  0) -> F(X);
times(F, X, N) -> F(X), times(F, X, N-1).
