:- module(_, [],
    [
        assertions,
        basicmodes,
        regtypes,
        nativeprops,
        datafacts,
        ciaopp(ciaopp_options)
    ]).

%------------------------------------------------------------------------

:- doc(title, "Analyze driver (monolithic)").
% TODO: add incremental/modular (with parts as a plugin)?

:- doc(usage, "@tt{:- use_module(ciaopp(analyze_driver))}.
   This module is loaded by default in the CiaoPP toplevel and
   reexported from the @lib{ciaopp} module.").

:- doc(module, "This module provides the main entry points for for
   performing analysis and assertion checking. It requires loading the
   program before (e.g., with @lib{frontend_driver}).

   @section{Adding new analysis}

   To include a new analysis, add a clause for @tt{analyze/2} (and for
   @tt{analysis/1}).

   As an alternative, you can add clauses for the multifile predicates
   @tt{analysis/4} and @tt{analysis/1}, directly in your own sources.

   See the file @tt{examples/Extending/myanalyzer.pl} in the source
   directory for an example of this.
").

:- doc(bug,"3. Program point compile time checking with the det and nf
   domain needs some work. It is now turned off since it loops").
:- doc(bug,"4. Analysis with res_plai of transformed programs(with
   unfold_entry) considers cost of some of the clauses that always
   fail and does not belong to original source language.").

% ---------------------------------------------------------------------------
% (Common)
:- use_module(engine(messages_basic), [message/2]). %% [IG] For errors
:- use_module(ciaopp(ciaopp_log), [pplog/2]).
:- use_module(ciaopp(analysis_stats), [pp_statistics/2]).

:- use_module(ciaopp(preprocess_flags),
    [current_pp_flag/2, set_pp_flag/2, push_pp_flag/2, pop_pp_flag/1]).

% ===========================================================================
:- doc(section, "Analyze").

%------------------------------------------------------------------------
:- doc(subsection, "Used analysis domains").

:- use_module(ciaopp(infer/infer_db), [domain/1]).

:- export(assert_domain/1).
assert_domain(AbsInt):-
    current_fact(domain(AbsInt)), !.
assert_domain(AbsInt):-
    assertz_fact(domain(AbsInt)).

cleanup_domain :-
    retractall_fact(domain(_)).

:- export(last_domain_used/1).
% Last domain used
last_domain_used(AbsInt) :-
    domain(AbsInt0),
    aidomain(AbsInt0), !,
    AbsInt = AbsInt0.

% ---------------------------------------------------------------------------
:- doc(subsection, "Interface to analysis").

% (Register)

:- use_package(ciaopp(analysis_register)).

:- if(defined(with_fullpp)).
:- use_module(library(compiler), [use_module/1]).

analysis_needs_load(Analysis) :-
    lazy_analysis(Analysis),
    \+ loaded_analysis(Analysis).

load_analysis(Analysis) :-
    analysis_module(Analysis, Module),
    use_module(Module).
:- endif. % with_fullpp

% (Hooks)

:- push_prolog_flag(multi_arity_warnings,off).

:- pred analysis(Analysis,Clauses,Dictionaries,Info) : analysis(Analysis)
    # "Performs @var{Analysis} on program @var{Clauses}.".
:- multifile analysis/4.

:- prop analysis(Analysis)
    # "@var{Analysis} is a valid analysis identifier.".
:- multifile analysis/1.

:- if(defined(with_fullpp)).
analysis(nfg). % TODO: why not in aidomain/1
analysis(seff). % TODO: why not in aidomain/1
analysis(res_plai). % TODO: why not in aidomain/1
analysis(res_plai_stprf). % TODO: why not in aidomain/1
analysis(sized_types). % TODO: why not in aidomain/1
analysis(AbsInt):- aidomain(AbsInt), !.
analysis(Analysis) :- lazy_analysis(Analysis), !.
:- endif. % with_fullpp

:- pop_prolog_flag(multi_arity_warnings).

% for documenting the multifile aidomain/1
% No way! :- use_module(ciaopp(plai/domains)).
:- doc(aidomain/1,"See the chapter on @tt{domains}.").
:- multifile aidomain/1.

% ---------------------------------------------------------------------------
:- doc(subsection, "Analysis").

:- use_module(ciaopp(p_unit), [program/2, push_history/1]).

:- if(defined(with_fullpp)).
% (Reexport for documentation)
:- reexport(ciaopp(plai/trace_fixp), [trace_fixp/1]). % for documentation
:- use_module(ciaopp(plai/trace_fixp), [trace_option/1]). % for documentation
:- use_module(ciaopp(plai/trace_fixp), [trace_init/0, trace_end/0]).
:- doc(doinclude,trace_fixp/1).
:- endif. % with_fullpp

:- use_module(ciaopp(p_unit/itf_db), [curr_file/2]).

:- if(defined(with_fullpp)).
% (support for incremental analysis)
:- use_module(ciaopp(plai/incanal), [incremental_analyze/2]).
% (support for intermodular analysis)
:- use_module(ciaopp(plai/intermod), [intermod_analyze/3]).
:- endif. % with_fullpp

:- if(defined(with_fullpp)).
:- use_module(ciaopp(plai), [plai/5, mod_plai/5, is_checker/1]).
%
:- if(defined(has_ciaopp_cost)).
:- use_module(domain(resources/reachability),[perform_reachability_analysis/1]).
:- endif.
%
:- use_module(ciaopp(infer/vartypes), [gather_vartypes/2]).
:- if(defined(has_ciaopp_cost)).
:- use_module(ciaopp(nfgraph/infernf), [non_failure_analysis/6]).
:- endif.
:- use_module(ciaopp(infer/inferseff), [analyze_side_effects/1]).
:- use_module(ciaopp(infer/infer_db), [cleanup_infer_db/1]).

:- use_module(typeslib(typeslib), [simplify_step2/0]).

% statistics (from intermod)
:- use_module(ciaopp(analysis_stats)).
:- endif. % with_fullpp

:- export(analyze/1).
:- pred analyze(-Analysis) => analysis
# "Returns on backtracking all available analyses.".
% TODO: remove previous assertion
:- pred analyze(+Analysis) : analysis + (not_fails, no_choicepoints)
  # "Analyzes the current module with @var{Analysis}. If the intermod flag is
    not off, this predicate may call @pred{module/1}.".
analyze(Analysis):- var(Analysis), !, analysis(Analysis).
analyze(Analysis):- analyze(Analysis,_),!. % TODO: remove cut

:- export(analyze/2).
:- pred analyze(+Analysis,-Info)
  # "Same as analyze(@var{Analysis}) but in @var{Info} returns statistics (time
    and memory).".
:- if(defined(with_fullpp)).
analyze(Analysis,Info):-
    \+ current_pp_flag(intermod, off), !,
    % push_pp_flag(entry_policy,force),  %% needed for generating proper output!
    curr_file(File,_),
    intermod_analyze(Analysis,File,Info).
    %       pop_pp_flag(entry_policy)
:- endif. % with_fullpp
analyze(Analysis,Info):-
    analyze1(Analysis,Info).

:- export(analyze1/2).
analyze1(AbsInt,Info) :- ( AbsInt = [] ; AbsInt = [_|_] ), !,
    analyze1_several_domains(AbsInt,[],Info).
:- if(defined(with_fullpp)).
analyze1(Analysis,Info):-
    current_pp_flag(incremental, on), !,
    trace_init,
    incremental_analyze(Analysis, Info),
    add_stat(ana, Info),
    % TODO: does incremental_analyze call assert_domain/1? (BEFORE COMMIT)
    trace_end.
analyze1(Analysis,Info):-
    trace_init,
    analysis(Analysis), !,
    curr_file(File,_),
    current_pp_flag(fixpoint,Fixp),
    %% *** Needs to be revised MH
    ( is_checker(Fixp) ->
        Header = '{Checking certificate for '
    ; Header = '{Analyzing '
    ),
    pplog(analyze_module, [~~(Header),~~(File)]),
    program(Cls,Ds),
    push_history(Analysis), % TODO: check that this does not break intermod_analyze
    analyze_(Analysis,Cls,Ds,Info,step1), % TODO:[new-resources] are two steps really needed? (JF)
    assert_domain(Analysis),
    pplog(analyze_module, ['}']),
    trace_end, !. % TODO: remove cut
:- endif. % with_fullpp
analyze1(Analysis,_Info):-
    message(error0, ['{Not a valid analysis: ',~~(Analysis),'}']),
    fail.

% Analyzes the program for the domains in the list
analyze1_several_domains([], TotalInfo, TotalInfo).
analyze1_several_domains([AbsInt|As], TotalInfo0, TotalInfo):-
    analyze1(AbsInt,Info),
    % TODO: move to a separate module
    add_to_info(Info,TotalInfo0,TotalInfo1),
    analyze1_several_domains(As, TotalInfo1, TotalInfo).

% ---------------------------------------------------------------------------

not_intermod(AbsInt) :-
    ( \+ current_pp_flag(intermod, off) ->
        message(error0, ['{Not implemented in modular analysis yet: ',~~(AbsInt),'}']),
        fail
    ; true
    ).

% take care of incompatibilities here!
:- if(defined(with_fullpp)).
:- if(defined(has_ciaopp_cost)).
analyze_(nfg,Cls,_Ds,nfinfo(TimeNf,Num_Pred,Num_NF_Pred,NCov),_):- !,
    not_intermod(nfg),
    cleanup_infer_db(nfg),
    cleanup_infer_db(vartypes),
    gather_vartypes(Cls,Trusts),
    non_failure_analysis(Cls,Trusts,TimeNf,Num_Pred,Num_NF_Pred,NCov).
analyze_(seff,Cls,_Ds,_Info,_):- !,
    not_intermod(nfg),
    analyze_side_effects(Cls).
analyze_(res_plai,Cls,Ds,Info,step1):-!,
    not_intermod(res_plai),
    % Previous informations
    %analyze_(eterms,Cls,Ds,_InfoEterms,_),
    %analyze_(shfr,Cls,Ds,_InfoShFr,_),
    analyze_(det,Cls,Ds,_InfoDet,_),
    analyze_(nf,Cls,Ds,_InfoNf,_),
    % Compute type information
    analyze_(etermsvar,Cls,Ds,_InfoEtermsVar,_),
    %typeslib:simplify_step1,
    ( simplify_step2 -> true ; true ), % TODO:[new-resources] this should not fail!
    % Analyze resources
    % ( current_pp_flag(perform_static_profiling,yes) ->
    %    push_pp_flag(fixpoint,plai_sp)
    % ; true
    % ),
    analyze_(res_plai,Cls,Ds,Info,step2),
    % ( current_pp_flag(perform_static_profiling,yes) ->
    %    pop_pp_flag(fixpoint)
    % ; true
    % ),
    handle_eqs(res_plai).
analyze_(res_plai_stprf,Cls,Ds,Info,step1):-!,
    not_intermod(res_plai_stprf),
    perform_reachability_analysis(Cls),
    % Previous informations
    %analyze_(eterms,Cls,Ds,_InfoEterms,_),
    %analyze_(shfr,Cls,Ds,_InfoShFr,_),
    analyze_(det,Cls,Ds,_InfoDet,_),
    analyze_(nf,Cls,Ds,_InfoNf,_),
    % Compute type information
    analyze_(etermsvar,Cls,Ds,_InfoEtermsVar,_),
    %typeslib:simplify_step1,
    ( simplify_step2 -> true ; true ), % TODO:[new-resources] this should not fail!
    % Analyze resources
    analyze_(res_plai_stprf,Cls,Ds,Info,step2),
    handle_eqs(res_plai_stprf).
analyze_(sized_types,Cls,Ds,Info,step1):-!,
    not_intermod(sized_types),
    ( simplify_step2 -> true ; true ), % TODO:[new-resources] this should not fail!
    analyze_(sized_types,Cls,Ds,Info,step2),
    handle_eqs(sized_types).
:- endif.
%
analyze_(Analysis,Cls,Ds,Info,_):- % TODO:[new-resources] should it be here? (JF) % TODO: probably wrong
    ( analysis_needs_load(Analysis) ->
        load_analysis(Analysis)
    ; true
    ),
    analysis(Analysis,Cls,Ds,Info), !.
%
analyze_(AbsInt,Cls,Ds,Info,_):-
    current_pp_flag(fixpoint,Fixp),
    % some domains may change widen and lub:
    current_pp_flag(widen,W),
    current_pp_flag(multi_success,L),
    ( current_pp_flag(intermod, off) ->
        add_packages_if_needed(AbsInt), % TODO: why not for intermod?
        plai(Cls,Ds,Fixp,AbsInt,Info)
    ; mod_plai(Cls,Ds,Fixp,AbsInt,Info),
      add_stat(ana, Info)
    ),
    set_pp_flag(multi_success,L),
    set_pp_flag(widen,W).
:- endif. % with_fullpp

:- if(defined(with_fullpp)).
:- use_module(ciaopp(p_unit), [inject_output_package/1]).
:- use_module(ciaopp(infer/infer_dom), [knows_of/2]).

:- pred add_packages_if_needed(Analysis) : analysis(Analysis)
    # "Add missing packages required for @var{Analysis} correct output.".
% --- DTM: This should be in the analysis itself

% TODO: around 10-20 ms each new package, optimize with caches? (JF)
add_packages_if_needed(shfr) :-
    !,
    inject_output_package(assertions),
    inject_output_package(nativeprops).
add_packages_if_needed(A) :-
    knows_of(regtypes, A),
    !,
    inject_output_package(assertions),
    inject_output_package(regtypes).
add_packages_if_needed(_) :-
    inject_output_package(assertions).
:- endif. % with_fullpp

% ---------------------------------------------------------------------------
% TODO:[new-resources] move to other module

:- if(defined(with_fullpp)).
:- if(defined(has_ciaopp_cost)).
:- use_module(domain(resources/recurrence_processing),
    [ solve_eqs/1,
      gather_and_solve_eqs/1,
      write_results/1,
      output_eqs_to_file/1]).

% Only relevant for res_plai, res_plai_stprf and sized_types 
handle_eqs(_):-
    current_pp_flag(postpone_solver,off),!.
handle_eqs(An):-
    gather_and_solve_eqs(An),
    write_results(An),
    curr_file(File,_),
    atom_concat(File,'.eqs',FileEqs),
    pplog(analyze_module, ['{Writing equations and results to ',~~(FileEqs),'}']),
    output_eqs_to_file(FileEqs).
:- endif.
:- endif. % with_fullpp

% ===========================================================================
:- doc(section, "Assertion checking").

:- if(defined(with_fullpp)).

:- use_module(ciaopp(infer/infer_db), [domain/1]).
:- use_module(ciaopp(infer/infer_dom), [knows_of/2]).

:- use_module(ciaopp(p_unit/itf_db), [curr_file/2]).

:- use_module(ciaopp(ctchecks/ctchecks_pred), [simplify_assertions_all/1]).
:- use_module(ciaopp(ctchecks/assrt_ctchecks_pp), [pp_compile_time_prog_types/3]).
:- use_module(ciaopp(ctchecks/ctchecks_pred_messages), [init_ctcheck_sum/0, 
    is_any_false/1, is_any_check/1]).

:- export(ctcheck_sum/1).
:- regtype ctcheck_sum/1.
ctcheck_sum(ok).
ctcheck_sum(warning).
ctcheck_sum(error).

:- export(acheck_summary/1).
:- pred acheck_summary(S): var(S) => ctcheck_sum(S)
# "Checks assertions w.r.t. analysis information. Upon success @var{S} 
  is bound to: ok (the compile-time checking process has generated no error 
  nor warning), warning (compile-time checking has not generated any error, 
  but there has been at least one warning) or error (at least one error has 
  been produced).".

acheck_summary(Sum) :-
    init_ctcheck_sum,
    acheck,
    decide_summary(Sum),!.

decide_summary(Sum) :-
    is_any_false(yes),!,
    Sum = error.
decide_summary(Sum) :-
    is_any_check(yes),
    current_pp_flag(ass_not_stat_eval, ANSE), 
    ( ANSE = warning,  Sum = warning
    ; ANSE = error,  Sum = error
    ; Sum = ok
    ),!. 
decide_summary(ok).

:- use_module(library(aggregates), [findall/3]).

:- export(acheck/0).
:- pred acheck # "Checks assertions w.r.t. analysis information, obtains from
   @pred{domain/1} which anaylses were run.".
acheck :-
    findall(AbsInt, domain(AbsInt), AbsInts),
    check_assertions(AbsInts).

:- export(acheck/1).
:- pred acheck(AbsInt) #"Checks assertions using the analysis information of
   @var{AbsInt}. The analysis must be present in CiaoPP (via analysis or restore
   dump).".
acheck(AbsInt):-
    domain(AbsInt), !, 
    check_assertions([AbsInt]).
acheck(AbsInt):-
    pplog(ctchecks, ['{Analysis ', ~~(AbsInt), ' not available for checking}']),
    fail.

:- pred check_assertions(+list).
check_assertions([]) :-
    pplog(ctchecks, ['{No analysis found for checking}']).
check_assertions(AbsInts):-
    pp_statistics(runtime,[CTime0,_]),
    curr_file(File,_),
    pplog(ctchecks, ['{Checking assertions of ',~~(File)]),
    perform_pred_ctchecks(AbsInts),
    perform_pp_ctchecks(AbsInts),
    pp_statistics(runtime,[CTime1,_]),
    CTime is CTime1 - CTime0,
    pplog(ctchecks, ['{assertions checked in ',time(CTime), ' msec.}']),
    pplog(ctchecks, ['}']).

%------------------------------------------------------------------------
perform_pred_ctchecks(AbsInts):-
    ( \+ current_pp_flag(pred_ctchecks,off) ->
        simplify_assertions_all(AbsInts)
    ; true ).

perform_pp_ctchecks(AbsInts) :-
    current_pp_flag(pp_ctchecks,on), !,
    program(Cls,Ds),
    pp_compile_time_prog_types(Cls,Ds,AbsInts).
perform_pp_ctchecks(_).

:- else. % \+ with_fullpp
% TODO: enable code above, make it modular

:- export(acheck/1).
acheck(_) :- fail.
:- export(acheck/0).
acheck.
:- export(acheck_summary/1).
acheck_summary(ok).

:- endif. % \+ with_fullpp

% ---------------------------------------------------------------------------
% TODO: cleanup for transform?

:- use_module(typeslib(typeslib), [cleanup_types/0]).

:- use_module(ciaopp(plai), [cleanup_plai/1]).
:- use_module(ciaopp(infer/infer_db), [cleanup_infer_db/1]).
:- use_module(ciaopp(infer/inferseff), [cleanup_seff/0]).
:- use_module(ciaopp(ctchecks/preproc_errors), [cleanup_errors/0]).

:- export(clean_analysis_info/0).
:- pred clean_analysis_info 
   # "Cleans all analysis info but keep the program as wether it would
      be just read.".

clean_analysis_info :-
    % cleanup database 
    cleanup_plai(_),
    cleanup_infer_db(_),
    cleanup_seff,
    cleanup_domain,
    % cleanup_types, % TODO: why not? JF
    cleanup_errors.

:- export(clean_analysis_info0/0).
clean_analysis_info0 :-
% DTM: it is done in define_new_module
%       cleanup_plai(_),
%       cleanup_infer_db(_),
%       cleanup_seff,
%       cleanup_p_abs,
%       cleanup_errors,
    cleanup_types,
    cleanup_domain.

:- if(defined(with_fullpp)).

:- use_module(ciaopp(plai), [cleanup_plai/1]).
:- use_module(ciaopp(plai/intermod_ops), [cleanup_p_abs/0]).
:- use_module(ciaopp(infer/inferseff), [cleanup_seff/0]).
:- use_module(ciaopp(infer/infer_db), [cleanup_infer_db/1]).

:- export(cleanup_for_codegen/0).
% TODO: why?
cleanup_for_codegen :-
    cleanup_plai(_),
    cleanup_infer_db(_),
    cleanup_seff,
    cleanup_types,
    cleanup_domain.
    % cleanup_errors. % TODO: why not?

:- endif. % with_fullpp
