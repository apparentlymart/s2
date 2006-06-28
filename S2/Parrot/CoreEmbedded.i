/*
 *  SWIG definition file for S2::Parrot::Embedded.
 */

%module "S2::Parrot::CoreEmbedded"

%{

#include <setjmp.h>
#include <string.h>

#include <parrot/embed.h>
#include <parrot/exit.h>
#include <parrot/extend.h>
#include <parrot/interpreter.h>

extern Parrot_PMC Parrot_find_global(Parrot_Interp, Parrot_STRING,
    Parrot_STRING);
extern Parrot_PMC Parrot_store_global(Parrot_Interp, Parrot_STRING,
    Parrot_STRING, Parrot_PMC);
extern Parrot_PackFile PackFile_new(Parrot_Interp, long is_mapped);
extern Parrot_PackFile PackFile_unpack(Parrot_Interp, Parrot_PackFile self,
    void *packed, long packed_len);

static Parrot_Interp shared_interpreter = NULL;
static int global_trace_flag = 0;
static jmp_buf springback_env;

%}

%inline %{

/*
 *  Initializes the embedded Parrot interpreter.
 */
int
init_embedded_parrot(int core, int trace)
{
    if (!shared_interpreter) {
        shared_interpreter = Parrot_new(NULL);

        Parrot_set_run_core(shared_interpreter, core);

        if (trace)
            Parrot_set_trace(shared_interpreter, trace);
    }
 
    global_trace_flag = trace;

    return 1;
}

/*
 *  Frees the embedded Parrot interpreter. We're at the mercy of Parrot here,
 *  which currently warns that it may memory leak. Nothing we can do,
 *  unfortunately, short of stuffing Parrot into a separate process or
 *  something like that.
 */

int
destroy_embedded_parrot()
{
    if (shared_interpreter) {
        Parrot_destroy(shared_interpreter);
        shared_interpreter = NULL;
    }

    return 1;
}

/*
 *  Reads and loads a packfile into the interpreter.
 */
int
read_bytecode_into_embedded_parrot(SV *code_ref)
{
    char *code;
    Parrot_PackFile pf;
    STRLEN code_len;
    SV *code_sv;

    if (!shared_interpreter)
        return 0;

    code_sv = SvRV(code_ref);
    code = SvPV(code_sv, code_len);

    pf = PackFile_new(shared_interpreter, 0);
    if (!PackFile_unpack(shared_interpreter, pf, code, code_len)) 
        return 0;

    Parrot_loadbc(shared_interpreter, pf);
    return 1;
}

/*
 *  Runs the bytecode that has just been loaded.
 */
int
run_bytecode_in_embedded_parrot(SV *in_argv)
{
    char **argv;
    int argc, i;
    AV *av_argv;
    SV **sv;

    if (SvROK(in_argv) && SvTYPE(SvRV(in_argv)) == SVt_PVAV)
        av_argv = (AV *)SvRV(in_argv);
    else
        av_argv = (AV *)sv_2mortal((SV *)newAV());

    argc = av_len(av_argv) + 1;
    argv = (char **)malloc(sizeof(char *) * (argc + 1));
    argv[0] = "s2";

    for (i = 0; i < argc; i++) {
        sv = av_fetch(av_argv, i, 0);
        if (!sv || !*sv || !SvPOK(*sv))
            continue;
        
        argv[i + 1] = SvPV_nolen(*sv);
    }

    if (!setjmp(springback_env))
        Parrot_runcode(shared_interpreter, argc, argv);

    return 1;
}

static void
springback()
{
    fputs("FOO\n", stderr);
    longjmp(springback_env, 1);
}

static Parrot_PMC
perl5_to_parrot_pmc(SV *sv)
{
    char *attr_name_cstr, *cstr, *type_str;
    int alen, i;
    AV *av;
    HE *he;
    HV *hv;
    I32 zlen;
    Parrot_PMC pmc, pmc_elem, pmc_key, pmc_private;
    Parrot_STRING pstr;
    STRLEN slen;
    SV **psv;

    if (sv == NULL)
        return Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
            shared_interpreter, "Undef"));

    if (SvROK(sv)) {
        if (SvTYPE(SvRV(sv)) == SVt_PVAV) {
            /* Array. */
            av = (AV *)SvRV(sv);
            alen = av_len(av);

            pmc = Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
                shared_interpreter, "ResizablePMCArray"));

            for (i = 0; i <= alen; i++) {
                psv = av_fetch(av, i, 0);
                if (psv == NULL || *psv == NULL)
                    continue;

                pmc_elem = perl5_to_parrot_pmc(*psv);
                if (!pmc_elem)
                    continue;

                Parrot_PMC_set_pmc_intkey(shared_interpreter, pmc, i,
                    pmc_elem);
            }

            return pmc;
        } else if (SvTYPE(SvRV(sv)) == SVt_PVHV) {
            hv = (HV *)SvRV(sv);

            /* FIXME: Design problem here. A clever user could create an S2
             * hash with a "_type" key and generate arbitrary S2 objects, even
             * with readonly values. Not fixable as long as S2 objects are
             * unblessed :( */
            if (hv_exists(hv, "_type", 5)) {
                /* S2 object. */
                psv = hv_fetch(hv, "_type", 5, 0);
                if (psv == NULL || *psv == NULL)
                    return Parrot_PMC_new(shared_interpreter,
                        Parrot_PMC_typenum(shared_interpreter, "Undef"));

                cstr = SvPV(*psv, slen);
                type_str = (char *)malloc(slen + 7);
                strcpy(type_str, "_s2::_");
                strncpy(type_str + 6, cstr, slen);
                type_str[slen + 7 - 1] = '\0';

                pmc = Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
                    shared_interpreter, type_str));

                free(type_str);

                pmc_private = Parrot_PMC_new(shared_interpreter,
                    Parrot_PMC_typenum(shared_interpreter, "Hash"));

                hv_iterinit(hv);
                while ((he = hv_iternext(hv))) {
                    cstr = hv_iterkey(he, &zlen);

                    if (cstr[0] == '_') {
                        /* Note that we have to trust the builtin code to be
                         * responsible and prefix its private variables with an
                         * underscore!
                         *
                         * TODO: Verify this against the metadata. */

                        pmc_elem = perl5_to_parrot_pmc(hv_iterval(hv, he));
                        if (!pmc_elem)
                            continue;

                        Parrot_PMC_set_pmc_keyed_str(shared_interpreter,
                            pmc_private, Parrot_new_string(shared_interpreter,
                            cstr, zlen, NULL, 0), pmc_elem);
                    } else {
                        pmc_elem = perl5_to_parrot_pmc(hv_iterval(hv, he));
                        if (!pmc_elem)
                            continue;
                        
                        attr_name_cstr = (char *)malloc(zlen + 2);
                        attr_name_cstr[0] = '_';
                        strncpy(attr_name_cstr + 1, cstr, zlen);
                        attr_name_cstr[zlen + 1] = '\0';

                        Parrot_PMC_set_attr_str(shared_interpreter, pmc,
                            Parrot_new_string(shared_interpreter,
                            attr_name_cstr, zlen + 1, NULL, 0), pmc_elem);
                    }
                }

                Parrot_PMC_set_attr_str(shared_interpreter, pmc,
                    Parrot_new_string(shared_interpreter, "private", 7, NULL,
                    0), pmc_private);

                return pmc;
            } else {
                /* Plain old hash. */
                pmc = Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
                    shared_interpreter, "Hash"));
                
                hv_iterinit(hv);
                while ((he = hv_iternext(hv))) {
                    cstr = hv_iterkey(he, &zlen);
                    pmc_key = Parrot_PMC_new(shared_interpreter,
                        Parrot_PMC_typenum(shared_interpreter, "String"));
                    Parrot_PMC_set_cstringn(shared_interpreter, pmc_key, cstr,
                        zlen);

                    pmc_elem = perl5_to_parrot_pmc(hv_iterval(hv, he));
                    if (!pmc_elem)
                        continue;
                    
                    Parrot_PMC_set_pmc_pmckey(shared_interpreter, pmc, pmc_key,
                        pmc_elem);
                }

                return pmc;
            }
        } else {
            return NULL;
        }
    } else if (SvOK(sv)) {
        /* Scalar. */
        cstr = SvPV(sv, slen);
        pstr = Parrot_new_string(shared_interpreter, cstr, slen, NULL, 0); 

        pmc = Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
            shared_interpreter, "String"));
        Parrot_PMC_set_string(shared_interpreter, pmc, pstr);

        return pmc;
    }

    return Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
        shared_interpreter, "Undef"));
}

static SV *
parrot_pmc_to_perl5(Parrot_PMC pmc)
{
    char *cstr, *attr_cstr;
    int i, len, type;
    AV *av;
    HV *hv;
    Parrot_Int zlen;
    Parrot_PMC elem, iter;
    Parrot_PMC class_pmc, class_name_pmc, metadata_pmc, private_pmc;
    Parrot_STRING pstr;
    SV **psv, *sv;

    type = Parrot_PMC_type(shared_interpreter, pmc);

    if (type == Parrot_PMC_typenum(shared_interpreter, "ResizablePMCArray")) {
        av = newAV();

        len = Parrot_PMC_get_intval(shared_interpreter, pmc);
        for (i = 0; i < len; i++) {
            /* fputs("calling array\n", stderr); */
            sv = parrot_pmc_to_perl5(Parrot_PMC_get_pmc_intkey(
                shared_interpreter, pmc, i));
            /* fputs("done calling array\n", stderr); */
            if (sv == NULL)
                continue;

            psv = av_store(av, i, sv);
            if (psv == NULL || *psv == NULL)
                SvREFCNT_dec(sv);
            else
                SvREFCNT_inc(sv);
        }

        return newRV_inc((SV *)av);
    } else if (type == Parrot_PMC_typenum(shared_interpreter, "Hash")) {
        hv = newHV();

        iter = Parrot_PMC_get_iter(shared_interpreter, pmc);
        while (Parrot_PMC_get_bool(shared_interpreter, iter)) {
            elem = Parrot_PMC_shift_pmc(shared_interpreter, iter);
            cstr = Parrot_PMC_get_cstringn(shared_interpreter, elem, &zlen);
            /* fputs("calling hash\n", stderr); */
            hv_store(hv, cstr, zlen, parrot_pmc_to_perl5(
                Parrot_PMC_get_pmc_keyed(shared_interpreter, pmc, elem)), 0);
            /* fputs("done calling hash\n", stderr); */
        }

        return newRV_inc((SV *)hv);
    } else if (type == Parrot_PMC_typenum(shared_interpreter, "String") ||
        type == Parrot_PMC_typenum(shared_interpreter, "Integer")) {
        cstr = Parrot_PMC_get_cstringn(shared_interpreter, pmc, &zlen);
        if (cstr == NULL)
            return &PL_sv_undef;

        return newSVpvn(cstr, zlen);
    } else if (type == Parrot_PMC_typenum(shared_interpreter, "Undef")) {
        return &PL_sv_undef;
    } else {
        class_pmc = Parrot_PMC_get_class(shared_interpreter, pmc);

        pstr = Parrot_PMC_name(shared_interpreter, class_pmc); 
        class_name_pmc = Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
            shared_interpreter, "String"));
        Parrot_PMC_set_string(shared_interpreter, class_name_pmc, pstr);
        cstr = Parrot_PMC_get_cstring(shared_interpreter, class_name_pmc);

        if (strncmp("_s2::_", cstr, 6))
            return &PL_sv_undef;

        Parrot_free_cstring(cstr);

        hv = newHV();

        /* Look up all the attributes in the metadata and extract them. */
        metadata_pmc = Parrot_find_global(shared_interpreter, pstr,
            Parrot_new_string(shared_interpreter, "_variable_metadata", 18,
            NULL, 0));
        
        iter = Parrot_PMC_get_iter(shared_interpreter, metadata_pmc);
        while (Parrot_PMC_get_bool(shared_interpreter, iter)) {
            elem = Parrot_PMC_shift_pmc(shared_interpreter, iter);
            cstr = Parrot_PMC_get_cstringn(shared_interpreter, elem, &zlen);

            attr_cstr = (char *)malloc(zlen + 2);
            attr_cstr[0] = '_';
            strncpy(attr_cstr + 1, cstr, zlen);
            attr_cstr[zlen + 1] = '\0';

            /* fputs("calling obj attr\n", stderr);
            fputs(cstr, stderr); */
            hv_store(hv, cstr, zlen, parrot_pmc_to_perl5(
                Parrot_PMC_get_attr_str(shared_interpreter, pmc,
                Parrot_new_string(shared_interpreter, attr_cstr, zlen + 1,
                NULL, 0))), 0);
            /* fputs("done calling obj attr\n", stderr); */

            Parrot_free_cstring(cstr); 
        }

        /* Add the private attributes to the hash, if present. */
        private_pmc = Parrot_PMC_get_attr_str(shared_interpreter, pmc,
            Parrot_new_string(shared_interpreter, "private", 7, NULL, 0));
        if (private_pmc != NULL && Parrot_PMC_type(shared_interpreter,
            private_pmc) == Parrot_PMC_typenum(shared_interpreter, "Hash")) {
            iter = Parrot_PMC_get_iter(shared_interpreter, private_pmc);
            while (Parrot_PMC_get_bool(shared_interpreter, iter)) {
                elem = Parrot_PMC_shift_pmc(shared_interpreter, iter);
                cstr = Parrot_PMC_get_cstringn(shared_interpreter, elem,
                    &zlen);
                /* fputs("calling obj privattr\n", stderr); */
                hv_store(hv, cstr, zlen, parrot_pmc_to_perl5(
                    Parrot_PMC_get_pmc_keyed(shared_interpreter, private_pmc,
                    elem)), 0);
                /* fputs("done calling obj privattr\n", stderr); */
            }
        }

        /* And we're done! Cross fingers... */
        return newRV_inc((SV *)hv);
    }
}

/*
 *  Runs the given Parrot function with the given arguments. The args will be
 *  converted to Parrot form, and the result of the function will be returned
 *  in Perl form. In other words, both the argument and return value are
 *  "toll-free bridged" between Perl5 and Parrot.
 *
 *  Note that the number of args is currently limited to at most 1, because
 *  variable arguments currently aren't exposed in the Parrot extension
 *  interface.
 */
int
run_function_in_embedded_parrot(char *name, SV *target, SV *args)
{
    AV *av_args;
    Parrot_PMC call_stub_pmc, exception_pmc, method_pmc, target_pmc;
    Parrot_STRING ns, str;

    ns = Parrot_new_string(shared_interpreter, "_s2", 3, NULL, 0);

    str = Parrot_new_string(shared_interpreter, "call_stub", 9, NULL, 0);
    call_stub_pmc = Parrot_find_global(shared_interpreter, ns, str);
    if (call_stub_pmc == NULL)
        return 0;

    str = Parrot_new_string(shared_interpreter, name, strlen(name), NULL, 0);
    method_pmc = Parrot_find_global(shared_interpreter, ns, str);
    if (method_pmc == NULL)
        return 0;

    if (args == NULL || !SvOK(args)) {
        av_args = newAV();
        args = newRV_inc((SV *)av_args);
    }

    /* TODO: targets */
    target_pmc = Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
        shared_interpreter, "Undef"));

    exception_pmc = (Parrot_PMC)Parrot_call_sub(shared_interpreter,
        call_stub_pmc, "PPPP", method_pmc, target_pmc,
        perl5_to_parrot_pmc(args));

    if (Parrot_PMC_type(shared_interpreter, exception_pmc) ==
        Parrot_PMC_typenum(shared_interpreter, "Undef"))
        return 1;   /* Looks good. */

    /* If we're here, we got an exception. Turn this into a Perl exception. */
    croak("%s", Parrot_PMC_get_cstring(shared_interpreter, exception_pmc));

    /* dead */
    return 0;
}

/*
 *  Copies the source PMC over the destination PMC. Knows about S2 classes
 *  and copies them appropriately.
 */
static int
copy_parrot_pmc(Parrot_PMC dest_pmc, Parrot_PMC src_pmc)
{
    char *cstr, *attr_cstr;
    int dest_type, type;
    Parrot_Int zlen;
    Parrot_PMC elem, iter;
    Parrot_PMC class_pmc, class_name_pmc, metadata_pmc;
    Parrot_PMC member_src_pmc;
    Parrot_STRING pstr;

    type = Parrot_PMC_type(shared_interpreter, src_pmc);
    dest_type = Parrot_PMC_type(shared_interpreter, dest_pmc);

    if (type == Parrot_PMC_typenum(shared_interpreter, "ResizablePMCArray") ||
        type == Parrot_PMC_typenum(shared_interpreter, "String") ||
        type == Parrot_PMC_typenum(shared_interpreter, "Integer") ||
        type == Parrot_PMC_typenum(shared_interpreter, "Undef"))
        Parrot_PMC_set_pmc(shared_interpreter, dest_pmc, src_pmc);
    else if (type == Parrot_PMC_typenum(shared_interpreter, "Hash")) {
        /* TODO: empty out the old hash */
        if (dest_type != type)
            return 0;           /* leave it alone */

        iter = Parrot_PMC_get_iter(shared_interpreter, src_pmc);
        while (Parrot_PMC_get_bool(shared_interpreter, iter)) {
            elem = Parrot_PMC_shift_pmc(shared_interpreter, iter);
            Parrot_PMC_set_pmc_keyed(shared_interpreter, dest_pmc, elem,
                Parrot_PMC_get_pmc_keyed(shared_interpreter, src_pmc, elem));
        }
    } else {
        if (dest_type == Parrot_PMC_typenum(shared_interpreter,
            "ResizablePMCArray") ||
            dest_type == Parrot_PMC_typenum(shared_interpreter, "Hash") ||
            dest_type == Parrot_PMC_typenum(shared_interpreter, "String") ||
            dest_type == Parrot_PMC_typenum(shared_interpreter, "Integer") ||
            dest_type == Parrot_PMC_typenum(shared_interpreter, "Undef"))
            return 0;           /* leave it alone */

        class_pmc = Parrot_PMC_get_class(shared_interpreter, src_pmc);

        pstr = Parrot_PMC_name(shared_interpreter, class_pmc);
        class_name_pmc = Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
            shared_interpreter, "String"));
        Parrot_PMC_set_string(shared_interpreter, class_name_pmc, pstr);
        cstr = Parrot_PMC_get_cstring(shared_interpreter, class_name_pmc);

        if (strncmp("_s2::_", cstr, 6))
            return 0;

        Parrot_free_cstring(cstr);

        /* Look up all the attributes in the metadata and extract them. */
        metadata_pmc = Parrot_find_global(shared_interpreter, pstr,
            Parrot_new_string(shared_interpreter, "_variable_metadata", 18,
            NULL, 0));
        
        iter = Parrot_PMC_get_iter(shared_interpreter, metadata_pmc);
        while (Parrot_PMC_get_bool(shared_interpreter, iter)) {
            elem = Parrot_PMC_shift_pmc(shared_interpreter, iter);
            cstr = Parrot_PMC_get_cstringn(shared_interpreter, elem, &zlen);

            attr_cstr = (char *)malloc(zlen + 2);
            attr_cstr[0] = '_';
            strncpy(attr_cstr + 1, cstr, zlen);
            attr_cstr[zlen + 1] = '\0';

            pstr = Parrot_new_string(shared_interpreter, attr_cstr, zlen + 1,
                NULL, 0);
            member_src_pmc = Parrot_PMC_get_attr_str(shared_interpreter,
                src_pmc, pstr);
            Parrot_PMC_set_attr_str(shared_interpreter, dest_pmc, pstr,
                member_src_pmc);

            Parrot_free_cstring(cstr); 
        }

        pstr = Parrot_new_string(shared_interpreter, "private", 7, NULL, 0);
        member_src_pmc = Parrot_PMC_get_attr_str(shared_interpreter, src_pmc,
            pstr);
        Parrot_PMC_set_attr_str(shared_interpreter, dest_pmc, pstr,
            member_src_pmc);
    }

    return 1;
}

/*
 *  The bridge between Parrot and Perl5 subs.
 */
static Parrot_PMC
perl_nci_callback(Parrot_Interp interpreter, Parrot_PMC args_pmc, Parrot_STRING
    sub_name_pstring)
{
    char *sub_name_cstr;
    int i, len, result;
    AV *args_av = NULL;
    Parrot_PMC arg_pmc, iter_pmc, ret_pmc, sub_name_pmc;
    SV *args_sv, **arg_psv, *ret_sv;

    /* Roundabout way to get this, but it avoids mucking around in Parrot
     * internals. */
    sub_name_pmc = Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
        shared_interpreter, "String"));
    Parrot_PMC_set_string(shared_interpreter, sub_name_pmc, sub_name_pstring);
    sub_name_cstr = Parrot_PMC_get_cstring(shared_interpreter, sub_name_pmc);

    ret_pmc = NULL;

    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);

    if (args_pmc != NULL) {
        args_sv = parrot_pmc_to_perl5(args_pmc);
        
        if (args_sv != NULL && SvOK(args_sv) && SvRV(args_sv) &&
            SvTYPE(SvRV(args_sv)) == SVt_PVAV) {
            args_av = (AV *)SvRV(args_sv);
            len = av_len(args_av);

            for (i = 0; i <= len; i++) {
                arg_psv = av_fetch(args_av, i, 0);
                if (arg_psv == NULL || *arg_psv == NULL)
                    XPUSHs(&PL_sv_undef);
                else
                    XPUSHs(*arg_psv);
            }
        }

        if (args_sv == NULL)
            abort();    /* FIXME */
    }

    PUTBACK;
    result = call_pv(sub_name_cstr, G_SCALAR | G_EVAL);
    SPAGAIN;

    if (SvTRUE(ERRSV)) {
        /* error */
        ret_sv = POPs;
        ret_pmc = perl5_to_parrot_pmc(ret_sv);
        /* TODO */
    } else {
        /* no error */
        ret_sv = POPs;
        ret_pmc = perl5_to_parrot_pmc(ret_sv);

        /* Functions might want to output something by changing their
         * arguments (e.g. class mutators). We have to synchronize the Perl
         * arguments with their Parrot counterparts. */

        if (args_av != NULL && args_pmc != NULL) {
            iter_pmc = Parrot_PMC_get_iter(shared_interpreter, args_pmc);
            for (i = 0; i <= len; i++) {
                if (!Parrot_PMC_get_bool(shared_interpreter, iter_pmc))
                    break;
                arg_pmc = Parrot_PMC_shift_pmc(shared_interpreter, iter_pmc);

                arg_psv = av_fetch(args_av, i, 0);
                if (arg_psv == NULL || *arg_psv == NULL)
                    continue;

                copy_parrot_pmc(arg_pmc, perl5_to_parrot_pmc(*arg_psv));
            }
        }
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return ret_pmc;
}

/*
 *  Initializes the NCI interface for calling Perl subs. You'll then able to
 *  call Perl subs by invoking the PMC at "_core_embedded::_call_perl" with
 *  a list of arguments as the first argument and the fully qualified name
 *  of the sub in the second argument. Cool!
 */

int
init_perl_nci()
{
    Parrot_PMC nci;

    nci = Parrot_PMC_new(shared_interpreter, Parrot_PMC_typenum(
        shared_interpreter, "NCI"));
    Parrot_register_pmc(shared_interpreter, nci);

    Parrot_PMC_set_pointer_keyed_str(shared_interpreter, nci,
        Parrot_new_string(shared_interpreter, "PJOS", 4, NULL, 0),
        perl_nci_callback);

    Parrot_store_global(shared_interpreter,
        Parrot_new_string(shared_interpreter, "_core_embedded", 14,
        NULL, 0), Parrot_new_string(shared_interpreter, "_call_perl",
        10, NULL, 0), nci);

    return 1;
}

%}

