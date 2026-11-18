class ZSP_CL_MCP_HANDLER definition
  public
  final
  create public .

public section.

  interfaces IF_HTTP_EXTENSION .

  data MO_SERVER type ref to IF_HTTP_SERVER .
protected section.
private section.

  methods EXECUTE_OPTIONS .
  methods EXECUTE_POST .
  methods EXECUTE_OTHERS .
  methods GET_JSON_PROPERTY
    importing
      !IV_JSON type STRING
      !IV_KEY type STRING
    returning
      value(RV_VAL) type STRING .
  methods JSON_ESCAPE
    importing
      !IV_RAW type STRING
    returning
      value(RV_SAFE) type STRING .
  methods HANDLE_MCP
    importing
      !IV_BODY type STRING
    returning
      value(RV_JSON) type STRING .
  methods TOOLS_SCHEMA
    returning
      value(RV_JSON) type STRING .
  methods CALL_TOOL
    importing
      !IV_NAME type STRING
      !IV_ARGS type STRING
    returning
      value(RV_JSON) type STRING .
  methods OK_CONTENT
    importing
      !IV_TEXT type STRING
    returning
      value(RV_JSON) type STRING .
  methods ERROR_CONTENT
    importing
      !IV_MESSAGE type STRING
    returning
      value(RV_JSON) type STRING .
ENDCLASS.



CLASS ZSP_CL_MCP_HANDLER IMPLEMENTATION.


  METHOD call_tool.

    CASE iv_name.
      WHEN 'searchFlights'.
        rv_json = zsp_cl_mcp_tools=>search_flights( iv_args = iv_args ).
      WHEN OTHERS.
        rv_json = error_content( |Unknown tool:{ iv_name }| ).
        return.
    ENDCASE.

    IF rv_json IS NOT INITIAL.
      rv_json = ok_content( rv_json ).
    ELSE.
      rv_json = error_content( |No Data found| ).
    ENDIF.

  ENDMETHOD.


  method ERROR_CONTENT.
    rv_json = '{ "isError":true, "content":[{"type":"text", "text":"' && json_Escape( iv_message ) && '"}]}'.
  endmethod.


  method EXECUTE_OPTIONS.

    mo_server->response->set_status( code = '200' reason = 'OK' ).
    mo_server->response->set_header_field( name = 'Access-Control-Allow-Origin' value = '*' ).
    mo_server->response->set_header_field( name = 'Access-Control-Allow-Methods' value = 'POST, OPTIONS' ).
    mo_server->response->set_header_field( name = 'Access-Control-Allow-Headers' value = 'Content-Type, Authorization, Accept, Mcp-Session-Id' ).

  endmethod.


  method EXECUTE_OTHERS.

    mo_server->response->set_status( code = '405' reason = 'Method Not Allowed' ).
    mo_server->response->set_header_field( name = 'Access-Control-Allow-Origin' value = '*' ).
    mo_server->response->set_header_field( name = 'Access-Control-Allow-Methods' value = 'POST, OPTIONS' ).

  endmethod.


  METHOD execute_post.

    DATA lv_body     TYPE string.
    DATA lv_response TYPE string.
    DATA lv_xbody    TYPE xstring.
    DATA lv_method   TYPE string.

    lv_xbody = mo_server->request->get_data( ).
    lv_body = cl_abap_codepage=>convert_from( source = lv_xbody codepage = 'UTF-8' ).
    lv_response = handle_mcp( lv_body ).
    IF lv_response IS INITIAL.
      mo_server->response->set_status( code = 202 reason = 'Accepted' ).
      RETURN.
    ENDIF.
    mo_server->response->set_status( code = 200 reason = 'OK' ).
    mo_server->response->set_header_field( name = 'Content-Type' value = 'application/json' ).
    mo_server->response->set_header_field( name = 'Access-Control-Allow-Origin' value = '*' ).
    mo_server->response->set_data( cl_abap_codepage=>convert_to( source = lv_response codepage = 'UTF-8' ) ) .


  ENDMETHOD.


  METHOD get_json_property.

    DATA lv_search TYPE string.
    DATA lv_pos  TYPE i.
    DATA lv_rest TYPE string.
    DATA lv_end  TYPE i.
    DATA lv_len  TYPE i.
    DATA lv_depth TYPE i.
    DATA lv_idx TYPE i.
    DATA lv_instr TYPE abap_bool.
    DATA lv_open TYPE c LENGTH 1.
    DATA lv_close TYPE c LENGTH 1.
    DATA lv_c    TYPE c LENGTH 1.
    DATA lv_slen TYPE i.
    DATA lv_prev TYPE i.
    DATA lv_cprev TYPE c LENGTH 1.
    lv_search = '"' && iv_key && '":'.
    FIND FIRST OCCURRENCE OF lv_search IN iv_json MATCH OFFSET lv_pos.
    IF sy-subrc <> 0. RETURN. ENDIF.
    lv_pos = lv_pos + strlen( lv_search ).
    lv_rest = iv_json+lv_pos.
    CONDENSE lv_rest.
    IF strlen( lv_rest ) = 0. RETURN. ENDIF.
    CASE lv_rest(1).
      WHEN '"'.
        lv_end = 1.
        lv_len = strlen( lv_rest ).
        WHILE lv_end < lv_len.
          IF lv_rest+lv_end(1) = '"'.
            EXIT.
          ENDIF.
          IF lv_rest+lv_end(1) = '\'.
            lv_end = lv_end + 1.
          ENDIF.
          lv_end = lv_end + 1.
        ENDWHILE.
        lv_slen = lv_end - 1.
        rv_val = lv_rest+1(lv_slen).
      WHEN '{' OR '['.
        lv_open = lv_rest(1).
        lv_close = COND #( WHEN lv_open = '{' THEN '}' ELSE ']' ).
        lv_len = strlen( lv_rest ).
        lv_depth = 0.
        lv_instr = abap_false.
        WHILE lv_idx < lv_len.
          lv_c = lv_rest+lv_idx(1).
          IF lv_c = '"' AND lv_instr = abap_false.
            lv_instr = abap_true.
          ELSEIF lv_c = '"' AND lv_instr = abap_true.
            IF lv_idx > 0.
              lv_prev = lv_idx - 1.
              lv_cprev = lv_rest+lv_prev(1).
              IF lv_cprev <> '\'.
                lv_instr = abap_false.
              ENDIF.
            ENDIF.
          ELSEIF lv_instr = abap_false.
            IF lv_c = lv_open.
              lv_depth = lv_depth + 1.
            ELSEIF lv_c = lv_close.
              lv_depth = lv_depth - 1.
              IF lv_depth = 0.
                lv_slen = lv_idx + 1.
                rv_val = lv_rest+0(lv_slen).
                RETURN.
              ENDIF.
            ENDIF.
          ENDIF.
          lv_idx = lv_idx + 1.
        ENDWHILE.
      WHEN OTHERS.
        lv_len = strlen( lv_rest ).
        WHILE lv_end < lv_len.
          lv_c = lv_rest+lv_end(1).
          IF lv_c = ',' OR lv_c = '}' OR lv_c = ']' OR lv_c = ' '.
            EXIT.
          ENDIF.
          lv_end = lv_end + 1.
        ENDWHILE.
        rv_val = lv_rest+0(lv_end).
    ENDCASE.
  ENDMETHOD.


  METHOD handle_mcp.

    DATA : lv_id      TYPE string,
           lv_method  TYPE string,
           lv_params  TYPE string,
           lv_version TYPE string,
           lv_name    TYPE string,
           lv_args    TYPE string,
           lv_result  TYPE string.

    lv_id = get_json_property( iv_json = iv_body iv_key = 'id' ).
    lv_method = get_json_property( iv_json = iv_body iv_key = 'method' ).

    CASE lv_method.
      WHEN 'initialize'.
        lv_params = get_json_property( iv_json = iv_body iv_key = 'params' ).
        IF lv_params IS NOT INITIAL.
          lv_version = get_json_property( iv_json = iv_body iv_key = 'protocolVersion' ).
        ELSE.
          lv_version = |{ sy-datum+0(4) }-{ sy-datum+4(2) }-{ sy-datum+6(2) }|.
        ENDIF.
        lv_result = '{"protocolVersion":"' && lv_version && '",'
         && '"capabilites":{"tools":{}},'
         && '"serverInfo":{"name":"TEST-MCP-SERVER", "version":"1.0"}}'.

      WHEN 'notifications/initialized'.
        rv_json = ''.
        RETURN.

      WHEN 'tools/list'.
        lv_result = tools_schema( ).

      WHEN 'tools/call'.
        lv_name = get_json_property( iv_json = iv_body iv_key = 'name' ).
        lv_args = get_json_property( iv_json = iv_body iv_key = 'arguments' ).
        IF lv_args IS INITIAL.
          lv_args = '{}'.
        ENDIF.
        lv_result = call_tool( iv_name = lv_name iv_args = lv_args ).

      WHEN OTHERS.
        rv_json = '{"jsonrpc":"2.0", "id":' && lv_id
        && ', "error":{"code":-32601,"message":"method not found: ' && json_escape( lv_method ) && '"}}'.
        RETURN.

    ENDCASE.

    IF lv_id CN '1234567890'.
      lv_id = '"' && lv_id && '"'.
    ENDIF.

    rv_json = '{"jsonrpc":"2.0", "id":' && lv_id && ', "result":' && lv_result && '}'.
  ENDMETHOD.


  METHOD if_http_extension~handle_request.

    DATA : lv_method TYPE string,
           lv_path   TYPE string.

    mo_Server = server.
    lv_method = server->request->get_method( ).
    lv_path = cl_http_utility=>if_http_utility~unescape_url( server->request->get_header_field( '~path' ) ).

    CASE lv_method.
      WHEN 'OPTIONS'.
        execute_options( ).
      WHEN 'POST'.
        execute_post( ).
      WHEN OTHERS.
        execute_others( ).
    ENDCASE.


  ENDMETHOD.


  METHOD json_escape.

    rv_safe = iv_raw.
    REPLACE ALL OCCURRENCES OF '\'
     IN rv_safe WITH '\\'.
    REPLACE ALL OCCURRENCES OF '“'
     IN rv_safe WITH '\“'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline
     IN rv_safe WITH '\n'.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>horizontal_tab
     IN rv_safe WITH '\t'.

  ENDMETHOD.


  method OK_CONTENT.
        rv_json = '{"content":[{"type":"text", "text":"' && json_Escape( iv_text ) && '"}]}'.
  endmethod.


  METHOD tools_schema.

    rv_json = '{"tools": ['
              && '{ "name": "searchFlights", "description": "Search for available flights",'
              && '"inputSchema": { "type": "object", "properties": { "origin": {'
              && ' "type": "string", "description": "Departure city" },"destination":'
              && '{ "type": "string", "description": "Arrival city" }, "date":'
              && '{ "type": "string", "format": "date", "description": "Travel date" } },'
              && '"required" : ["origin", "destination", "date"] }}]}'.
  ENDMETHOD.
ENDCLASS.
