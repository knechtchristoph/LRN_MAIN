CLASS /lrn/cl_setup_root DEFINITION
  PUBLIC
  ABSTRACT .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
    INTERFACES /lrn/if_setup.

    ALIASES courseid FOR /lrn/if_setup~courseid.
    ALIASES log FOR /lrn/if_setup~protocol.
    ALIASES run FOR /lrn/if_setup~run.

    METHODS constructor.

    CLASS-METHODS class_constructor.

*      Factory (for later use)
*    CLASS-METHODS create
*      IMPORTING
*        i_courseid      TYPE /lrn/courseid
*      RETURNING
*        VALUE(r_result) TYPE REF TO /lrn/if_setup
*      RAISING
*        lcx_no_authorization.
*  METHOD create.
*    DATA(class) = courses[  courseid = i_courseid ].
*    CREATE OBJECT r_result TYPE (class)
*      EXPORTING
*         i_courseid = i_courseid.
*  ENDMETHOD.

  PROTECTED SECTION.

* building blocks for course setup
    METHODS generate_data.
    METHODS get_exchange_rates.
    METHODS generate_s4d401_data.
    METHODS adjust_authorizations.
    METHODS generate_s4d430_data.
    METHODS generate_s4d437_data.

    CLASS-DATA users TYPE zcl_s4d_auth_utility=>tt_users.

  PRIVATE SECTION.

    TYPES: BEGIN OF st_course,
             courseid  TYPE /lrn/courseid,
             classname TYPE c LENGTH 30,
           END OF st_course.

    TYPES tt_courses TYPE STANDARD TABLE OF st_course
                     WITH NON-UNIQUE KEY courseid.

    TYPES tt_users TYPE STANDARD TABLE OF syuname
                     WITH NON-UNIQUE DEFAULT KEY.

    CLASS-DATA courses TYPE tt_courses.

ENDCLASS.



CLASS /LRN/CL_SETUP_ROOT IMPLEMENTATION.


  METHOD /lrn/if_setup~run.

    generate_data( ).
    get_exchange_rates( ).
    adjust_authorizations( ).

  ENDMETHOD.


  METHOD adjust_authorizations.

    CONSTANTS c_learner_br_tmpl TYPE zcl_s4d_auth_utility=>t_template VALUE 'ZABAP_LEARNER_BR'.
    CONSTANTS c_learner_br  TYPE zcl_s4d_auth_utility=>t_role_name VALUE 'ZZ_ABAP_LEARNER'.

    CONSTANTS c_dev_br_tmpl TYPE zcl_s4d_auth_utility=>t_template VALUE 'SAP_BR_DEVELOPER'.
    CONSTANTS c_dev_br  TYPE zcl_s4d_auth_utility=>t_role_name VALUE 'ZZ_DEVELOPER'.

    CONSTANTS c_dev_flp_space TYPE if_iam_business_role=>ty_flp_space_id VALUE 'SAP_BR_DEVELOPER'.
    CONSTANTS c_trans_rel_cat_id TYPE zcl_s4d_auth_utility=>t_catalog_id VALUE 'SAP_A4C_BC_TRN_REL_PC'.

*    DATA(sap_catalogs) = VALUE zcl_s4d_auth_utility=>tt_catalogs(
*                        ( 'SAP_A4C_BC_DEV_AIA_PC' )
*                        ( 'SAP_A4C_BC_DEV_AIQ_PC' )
*                        ( 'SAP_A4C_BC_DEV_ATC_RUN_PC' )
*                        ( 'SAP_A4C_BC_DEV_BCT_BCS_DIS_PC' )
*                        ( 'SAP_A4C_BC_DEV_BCT_BCS_PC' )
*                        ( 'SAP_A4C_BC_DEV_CLA_RUN_PC' )
*                        ( 'SAP_A4C_BC_DEV_DAT_PRV_PC' )
*                        ( 'SAP_A4C_BC_DEV_OBJ_DIS_PC' )
*                        ( 'SAP_A4C_BC_DEV_PC' )
*                        ( 'SAP_A4C_BC_DEV_RVB_DSP_PC' )
*                        ( 'SAP_A4C_BC_DEV_RVB_PC' )
*                        ( 'SAP_A4C_BC_DEV_SUP_PC' )
*                        ( 'SAP_A4C_BC_DEV_TRA_PC' )
*                        ( 'SAP_A4C_BC_DEV_TST_PC' )
*                        ( 'SAP_A4C_BC_DEV_UID_PC' )
*                        ( 'SAP_A4C_BC_TRN_MNG_PC' )
*                        ( 'SAP_CORE_BC_EXT_TST' )
*                        ( 'SAP_CORE_BC_TMC' )
*                     ).

*    zcl_s4d_auth_utility=>create_and_assign_role(
*      EXPORTING
*        i_role_name = c_learner_br
*        i_template  = c_learner_br_tmpl
*        i_users     = users
*        i_catalogs  = sap_catalogs
*        i_space     = c_space
*      CHANGING
*        c_log       = log
*    ).

    zcl_s4d_auth_utility=>create_and_assign_brole(
      EXPORTING
        i_template  = c_learner_br_tmpl
        i_role_name = c_learner_br
        i_users     = users
     IMPORTING
       e_brole     = DATA(learner_brole)
      CHANGING
        c_log       = log
    ).

    IF learner_brole IS NOT INITIAL.
      learner_brole->save(
          IMPORTING
            et_return = DATA(return) ).
      IF return IS NOT INITIAL.
        APPEND |Error saving role { learner_brole->get_id( ) }.| TO log.
        CLEAR return.
      ELSE.
        APPEND |Saved role { learner_brole->get_id( ) }.| TO log.
      ENDIF.
    ENDIF.



    zcl_s4d_auth_utility=>create_and_assign_brole(
     EXPORTING
       i_template  = c_dev_br_tmpl
       i_role_name = c_dev_br
       i_users     = users
     IMPORTING
       e_brole     = DATA(dev_brole)
     CHANGING
       c_log       = log
   ).

    IF dev_brole IS NOT INITIAL.
*     Add FLP Space to Business Role
      dev_brole->add_flp_space(
      EXPORTING
        iv_flp_space_id = c_dev_flp_space
      IMPORTING
        et_return       = return
    ).
      IF return IS NOT INITIAL.
        APPEND return[ 1 ]-message TO log.
        CLEAR return.
      ELSE.
        APPEND |Added Fiori launchpad space { c_dev_flp_space } to business role { dev_brole->get_id( ) }| TO log.
      ENDIF.


*     Remove Transport Release Management catalog from Business Role
      dev_brole->remove_business_catalog(
        EXPORTING
          iv_bu_catalog_id = c_trans_rel_cat_id
        IMPORTING
          et_return        = return
      ).

      IF return IS NOT INITIAL.
        APPEND return[ 1 ]-message TO log.
        CLEAR return.
      ELSE.
        APPEND |Removed catalog { c_trans_rel_cat_id } from business role { dev_brole->get_id( ) }| TO log.
      ENDIF.


      dev_brole->save(
         IMPORTING
           et_return = return ).
      IF return IS NOT INITIAL.
        APPEND |Error saving role { dev_brole->get_id( ) }.| TO log.
        CLEAR return.
      ELSE.
        APPEND |Saved role { dev_brole->get_id( ) }.| TO log.
      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD class_constructor.

    TYPES n2 TYPE n LENGTH 2.

    courses = VALUE #( ( courseid = 'S4D400' classname = '/LRN/CL_SETUP_S4D400' )
                       ( courseid = 'S4D401' classname = '/LRN/CL_SETUP_S4D401' )
                       ( courseid = 'S4D430' classname = '/LRN/CL_SETUP_S4D430' )
                       ( courseid = 'S4D437' classname = '/LRN/CL_SETUP_S4D437' )
                       ( courseid = 'S4Dnnn' classname = '/LRN/CL_SETUP_LSA'    )
                     ).

    SELECT
      FROM i_businessuserbasic
    FIELDS userid
     WHERE firstname LIKE 'TRAIN-%'
        OR userid = @sy-uname
  ORDER BY firstname
      INTO TABLE @users.
    "Only empty if current user has insufficient authorizations to read user data
  ENDMETHOD.


  METHOD constructor.

* set course ID
    TRY.
        DATA(my_name) = cl_abap_typedescr=>describe_by_object_ref(  me )->get_relative_name(  ).
        courseid      = courses[ classname = my_name ]-courseid.

      CATCH cx_sy_itab_line_not_found.
        courseid = 'Unknown'.
    ENDTRY.

    APPEND |Perform setup for { courseid }.|
        TO me->log.

  ENDMETHOD.


  METHOD generate_data.

    SELECT FROM /dmo/i_carrier
      FIELDS COUNT(*)
      INTO @DATA(carrier_count).

    IF carrier_count IS NOT INITIAL.
      APPEND `Flight model data already exists` TO log.
    ELSE.
      "Call Console app with redirected console output
      DATA(out_local) = NEW lcl_out( ).
      DATA(generator) = NEW /dmo/cl_flight_data_generator( ).

      generator->if_oo_adt_classrun~main( out = out_local ).

      "Cleanup protocol
      DELETE out_local->log WHERE table_line CP `*-->*`.

      " Store protocol
      APPEND LINES OF out_local->log TO me->log.

    ENDIF.

  ENDMETHOD.


  METHOD generate_s4d401_data.

    SELECT FROM /lrn/i_carrier
      FIELDS COUNT(*)
      INTO @DATA(carrier_count).

    IF carrier_count IS NOT INITIAL.
      APPEND `Learning specific data already generated` TO log.
    ELSE.

      " Call Console app with redirected console output
      DATA(out_local) = NEW lcl_out( ).
      DATA(generator) = NEW /lrn/cl_s4d401_generator( ).
      generator->if_oo_adt_classrun~main( out = out_local ).

      " Store protocol
      APPEND LINES OF out_local->log TO me->log.

    ENDIF.

  ENDMETHOD.


  METHOD generate_s4d430_data.

    SELECT FROM /lrn/c_employee_ann
      FIELDS COUNT(*)
      INTO @DATA(employee_count).

    IF employee_count IS NOT INITIAL.
      APPEND `Learning specific data already generated` TO log.
    ELSE.

      " Call Console app with redirected console output
      DATA(out_local) = NEW lcl_out( ).
      DATA(generator) = NEW /lrn/cl_s4d430_generator( ).
      generator->if_oo_adt_classrun~main( out = out_local ).

      " Store protocol
      APPEND LINES OF out_local->log TO me->log.

    ENDIF.

  ENDMETHOD.


  METHOD generate_s4d437_data.

    SELECT FROM /lrn/437a_c_travel
      FIELDS COUNT(*)
      INTO @DATA(travel_count).

    IF travel_count IS NOT INITIAL.
      APPEND `Learning specific data already generated` TO log.
    ELSE.

      " Call Console app with redirected console output
      DATA(out_local) = NEW lcl_out( ).
      DATA(generator) = NEW /lrn/cl_s4d437_generator( ).
      generator->if_oo_adt_classrun~main( out = out_local ).

      " Store protocol
      APPEND LINES OF out_local->log TO me->log.

    ENDIF.

  ENDMETHOD.


  METHOD get_exchange_rates.

    " Call Console app with redirected console output
    DATA(out_local) = NEW lcl_out( ).
    DATA(importer) = NEW zcl_ecb_exchange_rates_xml( ).

    importer->if_oo_adt_classrun~main( out = out_local ).

    " Cleanup protocol
    DELETE out_local->log WHERE    table_line CP `RATE_TYPE*`
                                OR table_line CP ` M *`
                                OR table_line CP `*Entry already exists;*`
                                OR table_line CP `*No entries have been written*`.

    " Store protocol
    IF out_local->log IS NOT INITIAL.
      APPEND LINES OF out_local->log TO me->log.
    ELSE.
      APPEND `Import of exchange rates finished successfully` TO me->log.
    ENDIF.

  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    TRY.
        run( ).

        APPEND |Finished setup for { courseid }.|
               TO me->log.

      CATCH /lrn/cx_no_authorization.

        APPEND `You are not authorized to execute this course setup.`
               TO me->log.

        APPEND |Setup for {  courseid } failed!!!!|
               TO me->log.

    ENDTRY.

    out->write( me->log ).

  ENDMETHOD.
ENDCLASS.
