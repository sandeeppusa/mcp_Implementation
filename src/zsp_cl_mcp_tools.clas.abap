class ZSP_CL_MCP_TOOLS definition
  public
  final
  create public .

public section.

  class-methods SEARCH_FLIGHTS
    importing
      !IV_ARGS type STRING
    returning
      value(RV_RESULT) type STRING .
protected section.
private section.
ENDCLASS.



CLASS ZSP_CL_MCP_TOOLS IMPLEMENTATION.


  METHOD search_flights.

    TYPES : BEGIN OF ty_flights,
              origin      TYPE string,
              destination TYPE string,
              date        TYPE string,
            END OF ty_flights.

    DATA : ls_flight_details TYPE ty_flights.

    /ui2/cl_json=>deserialize(
    EXPORTING
      json = iv_args
    CHANGING
      data = ls_flight_details ).

    SELECT * FROM sflights
      INTO TABLE  @DATA(lt_sflights)
      WHERE cityfrom = @ls_flight_details-origin
      AND cityto = @ls_flight_details-destination
      AND fldate = @ls_flight_details-date.
    IF sy-subrc = 0.
      CALL METHOD /ui2/cl_json=>serialize
        EXPORTING
          data   = lt_sflights
        RECEIVING
          r_json = rv_result.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
