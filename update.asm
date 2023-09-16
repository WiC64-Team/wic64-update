; ---------------------------------------------------------------------------

; TODO: Handle HTTP failures when fetching version information

!addr zp1 = $22
!addr zp2 = $50

!addr draw_menu_header = $ce0c
!addr menu_header_title = $cfa3

; ---------------------------------------------------------------------------

* = $0801 ; 10 SYS 2064 ($0810)
!byte $0c, $08, $0a, $00, $9e, $20, $32, $30, $36, $34, $00, $00, $00

* = $0810
jmp main

; ---------------------------------------------------------------------------

wic64_include_return_to_portal = 1
!src "wic64.asm"
!src "util.asm"

; ---------------------------------------------------------------------------

test_menu_code_loaded: !zone {
    lda draw_menu_header
    cmp #$4c
    bne .not_loaded

    lda draw_menu_header+1
    cmp #$46
    bne .not_loaded

    lda draw_menu_header+2
    cmp #$ce
    bne .not_loaded

.loaded
    clc
    rts

.not_loaded
    sec
    rts
}
; ---------------------------------------------------------------------------

!macro print_version .addr {
    lda .addr
    bne +

    +print none_text
    jmp .done

+   jsr print_dec
    jsr dot

    lda .addr+1
    jsr print_dec
    jsr dot

    lda .addr+2
    jsr print_dec

    lda .addr+3
    beq .done

    jsr dash
    lda .addr+3
    jsr print_dec

.done:
}

; ---------------------------------------------------------------------------

compare_versions: !zone compare_versions {
    ldy #$03

-   lda (zp1),y
    cmp (zp2),y
    bne .not_equal
    dey
    bpl -

.equal:
    ldy #$04
    lda #$00
    sta (zp1),y
    clc
    rts

.not_equal:
    ldy #$04
    lda #$01
    sta (zp1),y
    sec
    rts

.done:
}

!macro compare_versions .a, .b {
    +pointer zp1, .a
    +pointer zp2, .b
    jsr compare_versions
}

; ---------------------------------------------------------------------------

continue_or_quit:
-   jsr wait_any_key

    ++  +scan key_f5
    bne +
    jmp ++

+   +rts_to main

++  +scan key_stop
    bne +
    jmp ++

+   jsr return_to_portal
    jmp -

++  +scan key_esc
    bne +
    jmp ++

+   jsr return_to_portal
    jmp -

++  rts

continue_or_quit_text:
!text "=> pRESS ANY KEY TO CONTINUE", $0d, $00

; ---------------------------------------------------------------------------

!macro print_error_and_jmp .message, .addr {
    jsr red
    +print .message
    jsr green

    +print continue_or_quit_text
    jsr continue_or_quit

    jmp .addr
}

; ---------------------------------------------------------------------------

return_to_portal:
    ; clear keyboard buffer
    ; TODO: should be in portal startup
    lda #$00
    sta $c6

    +wic64_return_to_portal
    rts

; ---------------------------------------------------------------------------

!macro install .version, .query {

.ensure_version_exists:
    lda .version
    bne .ensure_version_is_not_installed_yet
    jmp .done

.ensure_version_is_not_installed_yet:
    lda .version+4
    bne .warn_about_unstable_version

    jsr yellow
    +print warning_installed_prefix
    +print_version .version
    +print warning_installed_postfix
    jsr green

    +print continue_or_quit_text
    jsr continue_or_quit

    jmp main

.warn_about_unstable_version:
    lda .version+3
    beq .prepare_url_query

    jsr yellow
    +print unstable_hint_text
    jsr green

    +print install_unstable_prompt
    jsr yes_or_no
    bcc .prepare_url_query
    jmp main

.prepare_url_query:
    ldx #$02
-   lda .query,x
    sta remote_request_query,x
    dex
    bpl -

.clear_url
    +fill install_request_url, $00, $ff

.execute_url_query
    +wic64_execute remote_request, install_request_url
    bcc .prepare_install_request
    +print_error_and_jmp timeout_error_text, main

.prepare_install_request
    +strlen install_request_url
    stx install_request_size
    +add_four_to install_request_size
    +fill install_response, $00, $ff

.execute_install_request
    +print installing_text
    +print_version .version
    +print elipsis_text

    jsr save_cursor_pos
    jsr start_of_line
    jsr spinner_start

    +wic64_execute install_request, install_response, $40
    bcc +
    +paragraph
    +print_error_and_jmp timeout_error_text, main

+   jsr spinner_stop

    lda #$00
    sta install_successful

+   lda install_response
    cmp #'0'
    beq +
    lda #$01
    sta install_successful

+   lda install_successful
    beq .install_success

.install_failure:
    jsr red
    lda #'x'
    jsr chrout
    jsr restore_cursor_pos
    +paragraph
    +print_ascii install_response+2
    jsr green

    +paragraph
    +print continue_or_quit_text
    jsr continue_or_quit
    jmp main

.install_success:
    lda #$ba
    jsr chrout
    jsr restore_cursor_pos
    +print_ascii install_response+2

.reboot:
    +newline
    +print rebooting_text
    +print elipsis_text

    jsr save_cursor_pos
    jsr start_of_line
    jsr spinner_start

    ; only send reboot request, then expect single handshake...

    lda #$10
    sta wic64_timeout
    +wic64_set_timeout $10
    +wic64_initialize
    +wic64_send_header reboot_request
    +wic64_wait_for_handshake
    +wic64_finalize

    lda #$01
    jsr delay

    jsr spinner_stop
    lda #$ba
    jsr chrout
    jsr restore_cursor_pos
    +print ok_text

    +newline
    +print installed_version_text

    jsr save_cursor_pos
    jsr start_of_line
    jsr spinner_start

    +fill installed_version_string_response, $00, $40
    +wic64_execute installed_version_string_request, installed_version_string_response
    bcc +
    +print_error_and_jmp timeout_error_text, main

+   jsr spinner_stop
    lda #$ba
    jsr chrout
    jsr restore_cursor_pos

    +print installed_version_string_response

    +paragraph
    +print continue_or_quit_text
    jsr continue_or_quit
    jmp main
.done
}

install_successful: !byte $01

current_stable_url_query: !text "csu"
previous_stable_url_query: !text "psu"
current_unstable_url_query: !text "cuu"
previous_unstable_url_query: !text "puu"

installing_text:
!text "  iNSTALLING VERSION ", $00

rebooting_text:
!text "  bOOTING INSTALLED FIRMWARE", $00

elipsis_text:
!text "... ", $00

ok_text:
!text "ok", $00

installed_version_text:
!text "  cONFIRMING VERSION... ", $00

warning_installed_prefix:
!text "vERSION ", $00

warning_installed_postfix:
!text " CURRENTLY INSTALLED", $0d, $0d, $00

unstable_hint_text:
!text "uNSTABLE VERSIONS CONTAIN EXPERIMENTAL", $0d
!text "CODE AND MAY CAUSE EXISTING PROGRAMS TO", $0d
!text "STOP WORKING. uSE AT YOUR OWN RISK.", $0d
!text $0d, $00

install_unstable_prompt:
!text "iNSTALL UNSTABLE VERSION? (y/n)", $0d, $0d, $00

reboot_request: !byte "W", $04, $00, $29

; ---------------------------------------------------------------------------

main:
    lda #$00
    sta $d020
    sta $d021

    jsr green
    jsr clrhome
    jsr lowercase

    jsr test_menu_code_loaded
    bcc +

    +print title_text
    jmp ++

+   +copy_string title_text, menu_header_title
    jsr draw_menu_header
    +plot 0, 4

++  jsr reverse_off

bail_on_legacy_firmware:
    +fill installed_version_string_response, $00, $40

    +wic64_execute installed_version_string_request, installed_version_string_response
    bcc +
    +print_error_and_jmp timeout_error_text, main

+   +strlen installed_version_string_response
    cpx #$04
    bne get_installed_version

    jsr red
    +print legacy_firmware_error_text

    jsr green
    +print legacy_firmware_help_text

    +print continue_or_quit_text
    jsr continue_or_quit
    jmp main

get_installed_version:
    +wic64_execute installed_version_request, installed_version
    bcc +
    +print_error_and_jmp timeout_error_text, main

+   +print installed_text
    jsr cyan
    +print_version installed_version
    jsr green

    lda installed_version+3
    beq +

    +print unstable_tag
    jmp ++

+   +print stable_tag

++  +paragraph

get_remote_versions:
    lda #'v'
    sta remote_request_query+2

    lda #'s'
    sta remote_request_query+1

get_current_stable_version:
    lda #'c'
    sta remote_request_query

    +wic64_execute remote_request, current_stable_version
    bcc +
    +print_error_and_jmp timeout_error_text, main

+   lda current_stable_version
    bne +
    jsr grey

+   +compare_versions current_stable_version, installed_version
    bcs +
    jsr cyan

+   +print current_stable_text
    +print_version current_stable_version
    +newline
    jsr green

get_previous_stable_version:
    lda #'p'
    sta remote_request_query

    +wic64_execute remote_request, previous_stable_version
    bcc +
    +print_error_and_jmp timeout_error_text, main

+   lda previous_stable_version
    bne +
    jsr grey

+   +compare_versions previous_stable_version, installed_version
    bcs +
    jsr cyan

+   +print previous_stable_text
    +print_version previous_stable_version
    +newline
    jsr green

get_current_unstable_version:
    lda #'u'
    sta remote_request_query+1

    lda #'c'
    sta remote_request_query

    +wic64_execute remote_request, current_unstable_version
    bcc +
    +print_error_and_jmp timeout_error_text, main

+   lda current_unstable_version
    bne +
    jsr grey

+   +compare_versions current_unstable_version, installed_version
    bcs +
    jsr cyan

+   +print current_unstable_text
    +print_version current_unstable_version
    +newline
    jsr green

get_previous_unstable_version:
    lda #'p'
    sta remote_request_query

    +wic64_execute remote_request, previous_unstable_version
    bcc +
    +print_error_and_jmp timeout_error_text, main

+   lda previous_unstable_version
    bne +
    jsr grey

+   +compare_versions previous_unstable_version, installed_version
    bcs +
    jsr cyan

+   +print previous_unstable_text
    +print_version previous_unstable_version
    +newline
    jsr green

prompt:
    +newline
    +print prompt_text

scan:
    jsr continue_or_quit

++  +scan key_one
    bne +
    jmp ++

+   +install current_stable_version, current_stable_url_query
    jmp scan

++  +scan key_two
    bne +
    jmp ++

+   +install previous_stable_version, previous_stable_url_query
    jmp scan

++  +scan key_three
    bne +
    jmp ++

+   +install current_unstable_version, current_unstable_url_query
    jmp scan

++  +scan key_four
    bne +
    jmp ++

+  +install previous_unstable_version, previous_unstable_url_query

++  jmp scan

; ---------------------------------------------------------------------------

legacy_firmware_error_text:
!text "!! lEGACY FIRMWARE VERSION DETECTED !!", $0d, $0d, $00

legacy_firmware_help_text:
!text "fIRMWARE VERSION 2.0.0 OR LATER IS", $0d
!text "REQUIRED TO RUN THIS PROGRAM.", $0d
!text $0d
!text "tO UPDATE TO A NEWER VERSION, VISIT", $0d
!text $0d
!text $9f, "     WWW.WIC64.COM/WIC64-FLASHER", $1e, $0d
!text $0d
!text $00

title_text:
!text "fIRMWARE uPDATE", $0d, $0d, $00

installed_text:
!text "iNSTALLED VERSION: ", $00

installed_tag:
!text " <=", $00

current_stable_text:
!text "1. cURRENT STABLE...... ", $00

previous_stable_text:
!text "2. pREVIOUS STABLE..... ", $00

current_unstable_text:
!text "3. cURRENT UNSTABLE.... ", $00

previous_unstable_text:
!text "4. pREVIOUS UNSTABLE... ", $00

stable_tag:
!text " (STABLE)", $00

unstable_tag:
!text " (UNSTABLE)", $00

none_text: !text "NONE", $00

prompt_text:
!text "=> sELECT VERSION TO INSTALL", $0d
!text $0d, $00

timeout_error_text:
!text "rEQUEST TIMEOUT", $0d, $0d, $00

installed_version_request:
!byte "W", $04, $00, $26

installed_version_string_request:
!byte "W", $04, $00, $00

installed_version_string_response:
!fill 64, 0

remote_request:
remote_request_header: !byte "W"
remote_request_size: !byte <remote_request_length, >remote_request_length
remote_request_cmd: !byte $01
remote_request_url: !text "http://www.henning-liebenau.de/update/update.php?q="
remote_request_query: !text "xxx"
remote_request_url_end:

remote_request_url_length = remote_request_url_end - remote_request_url
remote_request_length = remote_request_url_length + 4

installed_version:
!fill 4

current_stable_version:
!fill 4

current_stable_version_installed:
!byte $01

previous_stable_version:
!fill 4

previous_stable_version_installed:
!byte $01

current_unstable_version:
!fill 4

current_unstable_version_installed:
!byte $01

previous_unstable_version:
!fill 4

previous_unstable_version_installed:
!byte $01

install_request:
install_request_header: !byte "W"
install_request_size: !byte $00, $00
install_request_cmd: !byte $27
install_request_url: !fill 255

install_response: !fill 255

ping_request: !byte "W", $08, $00, $fe
ping_data: !text "ping"
ping_response: !byte $00, $00, $00, $00
