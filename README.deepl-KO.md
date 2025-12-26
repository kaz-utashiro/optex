# NAME

optex - 범용 명령 옵션 래퍼

# VERSION

Version 1.05

# SYNOPSIS

**옵텍스** _명령_ \[ **-M**_모듈_ \] ...

또는 _명령_ -> **옵텍스** 심볼릭 링크, 또는

**옵텍스** _옵션_ \[ -l | -m \] ...

    --link,   --ln  create symlink
    --unlink, --rm  remove symlink
    --ls            list link files
    --rc            list rc files
    --nop, -x       disable option processing
    --[no]module    disable module option on arguments

# DESCRIPTION

**옵텍스**는 Perl 모듈 [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX)를 사용하는 범용 명령 옵션 처리 래퍼입니다. 이를 통해 사용자는 시스템의 모든 명령에 대해 고유한 옵션 별칭을 정의하고 모듈 스타일의 확장성을 제공할 수 있습니다.

대상 명령은 인자로 주어집니다:

    % optex command

또는 **옵텍스**에 대한 심볼릭 링크 파일로 지정할 수 있습니다:

    command -> optex

구성 파일 `~/.optex.d/`_command_`.rc`가 존재하면 실행 전에 평가되고 명령 인수는 이를 사용하여 사전 처리됩니다.

## OPTION ALIASES

`-I[TIMESPEC]` 옵션이 없는 macOS의 `date` 명령을 생각해보세요. **옵텍스**를 사용하면 `~/.optex.d/date.rc` 파일에 다음 설정을 준비하여 이를 구현할 수 있습니다.

    option -I        -Idate
    option -Idate    +%F
    option -Iseconds +%FT%T%z
    option -Iminutes +%FT%H:%M%z
    option -Ihours   +%FT%H%z

    option --iso-8601         -I
    option --iso-8601=date    -Idate
    option --iso-8601=seconds -Iseconds
    option --iso-8601=minutes -Iminutes
    option --iso-8601=hours   -Ihours

그러면 다음 명령이 예상대로 작동합니다.

    % optex date -Iseconds

명령어 검색 경로에서 심볼릭 링크 `date -> optex`가 발견되면 표준 명령어와 동일하게 사용할 수 있지만 지원되지 않는 옵션을 사용할 수 있습니다.

    % date -Iseconds

공통 설정은 `~/.optex.d/default.rc` 파일에 저장되며, 해당 규칙은 **옵텍스**를 통해 실행되는 모든 명령에 적용됩니다.

사실 `--iso-8601` 옵션은 이렇게 더 간단하게 정의할 수 있습니다:

    option --iso-8601 -I$<shift>

이것은 거의 항상 정상적으로 작동하지만, 이렇게 다른 옵션 앞에 `--iso-8601` 옵션만 있으면 실패합니다:

    % date --iso-8601 -u

## COMMAND ALIASES

**옵텍스**의 명령어 별칭은 셸의 별칭 기능과 다르지 않지만, 도구나 스크립트에서 명령어로 실행할 수 있고 설정 파일에서 일괄적으로 관리할 수 있다는 점에서 효과적입니다.

명령 별칭은 다음과 같이 구성 파일(`~/.optex.d/config.toml`)에서 설정할 수 있습니다:

    [alias]
        tc = "optex -Mtextconv"

`tc`에서 `옵텍스`로 다음과 같이 심볼릭 링크를 만들 수 있습니다:

    % optex --ln tc

그리고 `PATH` 환경 설정에 `$HOME/.optex.d/bin`을 포함하세요.

`textconv` 모듈은 인자로 지정된 파일을 일반 텍스트로 변환하는 데 사용할 수 있습니다. 이렇게 정의된 Word 파일은 다음과 같이 비교할 수 있습니다.

    % tc diff A.docx B.docx

별칭 이름은 rc 파일 및 모듈 디렉토리를 찾는 데 사용됩니다. 위의 예에서는 `~/.optex.d/tc.rc`와 `~/.optex.d/tc/`가 참조됩니다.

구성 파일에 셸 스크립트를 작성할 수도 있습니다. 다음 예제에서는 C-shell `repeat` 명령을 구현합니다.

    [alias]
            repeat = [ 'bash', '-c', '''
                while getopts 'c:i:' OPT; do
                    case $OPT in
                        c) count=$OPTARG;;
                        i) sleep=$OPTARG;;
                    esac
                done; shift $((OPTIND - 1))
                case $1 in
                    [0-9]*) count=$1; shift;;
                esac
                while ((count--)); do
                    eval "$*"
                    [ "$sleep" ] && (( count > 0 )) && sleep $sleep
                done
            ''', 'repeat' ]

["구성 파일"](#구성-파일) 섹션을 읽습니다.

## MACROS

매크로 `define`을 사용하여 복잡한 문자열을 구성할 수 있습니다. 다음 예는 텍스트의 모음을 계산하는 awk 스크립트로, 파일 `~/.optex.d/awk.rc`에 선언됩니다.

    define __delete__ /[bcdfgkmnpsrtvwyz]e( |$)/
    define __match__  /ey|y[aeiou]*|[aeiou]+/
    define __count_vowels__ <<EOS
    {
        s = tolower($0);
        gsub(__delete__, " ", s);
        for (count=0; match(s, __match__); count++) {
            s=substr(s, RSTART + RLENGTH);
        }
        print count " " $0;
    }
    EOS
    option --vowels __count_vowels__

다음과 같이 사용할 수 있습니다:

    % awk --vowels /usr/share/dict/words

복잡한 옵션을 설정할 때는 `expand` 지시어가 유용합니다. `expand`는 `옵션`과 거의 동일하게 작동하지만 파일 범위 내에서만 유효하며 명령줄 옵션에는 사용할 수 없습니다.

    expand repository   ( -name .git -o -name .svn -o -name RCS )
    expand no_dots      ! -name .*
    expand no_version   ! -name *,v
    expand no_backup    ! -name *~
    expand no_image     ! -iname *.jpg  ! -iname *.jpeg \
                        ! -iname *.gif  ! -iname *.png
    expand no_archive   ! -iname *.tar  ! -iname *.tbz  ! -iname *.tgz
    expand no_pdf       ! -iname *.pdf

    option --clean \
            repository -prune -o \
            -type f \
            no_dots \
            no_version no_backup \
            no_image \
            no_archive \
            no_pdf

    % find . --clean -print

## MODULES

**옵텍스**는 모듈 확장도 지원합니다. `date`의 예에서 모듈 파일은 `~/.optex.d/date/` 디렉토리에 있습니다. 기본 모듈인 `~/.optex.d/date/default.pm`이 존재하면 실행할 때마다 자동으로 로드됩니다.

이것은 일반적인 Perl 모듈이므로 패키지 선언과 최종 참값이 필요합니다. 그 사이에 모든 종류의 Perl 코드를 넣을 수 있습니다. 예를 들어, 다음 프로그램은 `date` 명령을 실행하기 전에 환경 변수 `LANG`을 `C`로 설정합니다.

    package default;
    $ENV{LANG} = 'C';
    1;

    % /bin/date
    2017年 10月22日 日曜日 18時00分00秒 JST

    % date
    Sun Oct 22 18:00:00 JST 2017

다른 모듈은 `-M` 옵션을 사용하여 로드합니다. 다른 옵션과 달리 `-M`은 인자 목록의 맨 앞에 위치해야 합니다. `~/.optex.d/date/` 디렉토리에 있는 모듈 파일은 `date` 명령에만 사용됩니다. 모듈이 `~/.optex.d/` 디렉토리에 있으면 모든 명령어에서 사용할 수 있습니다.

`-Mes` 모듈을 사용하려면 다음과 같은 내용으로 `~/.optex.d/es.pm` 파일을 생성합니다.

    package es;
    $ENV{LANG} = 'es_ES';
    1;

    % date -Mes
    domingo, 22 de octubre de 2017, 18:00:00 JST

라이브러리 경로에서 지정한 모듈을 찾지 못하면 **옵텍스**는 옵션을 무시하고 즉시 인자 처리를 중지합니다. 무시된 옵션은 대상 명령으로 전달됩니다.

모듈은 서브루틴 호출에도 사용됩니다. `~/.optex.d/env.pm` 모듈이 다음과 같다고 가정해 보겠습니다:

    package env;
    sub setenv {
        while (($a, $b) = splice @_, 0, 2) {
            $ENV{$a} = $b;
        }
    }
    1;

그러면 좀 더 일반적인 방식으로 사용할 수 있습니다. 다음 예제에서는 첫 번째 형식이 읽기 쉽지만, 두 번째 형식은 이스케이프할 특수 문자가 없기 때문에 입력하기가 더 쉽습니다.

    % date -Menv::setenv(LANG=de_DE) # need shell quote
    % date -Menv::setenv=LANG=de_DE  # alternative format
    So 22 Okt 2017 18:00:00 JST

옵션 별칭은 모듈에서 파일 끝의 특수 리터럴 `__DATA__` 뒤에 선언할 수도 있습니다. 이를 사용하여 다양한 목적에 맞는 여러 옵션 집합을 준비할 수 있습니다. 일반 **i18n** 모듈을 생각해 보세요:

    package i18n;
    1;
    __DATA__
    option --cn -Menv::setenv(LANG=zh_CN) // 中国語 - 簡体字
    option --tw -Menv::setenv(LANG=zh_TW) // 中国語 - 繁体字
    option --us -Menv::setenv(LANG=en_US) // 英語
    option --fr -Menv::setenv(LANG=fr_FR) // フランス語
    option --de -Menv::setenv(LANG=de_DE) // ドイツ語
    option --it -Menv::setenv(LANG=it_IT) // イタリア語
    option --jp -Menv::setenv(LANG=ja_JP) // 日本語
    option --kr -Menv::setenv(LANG=ko_KR) // 韓国語
    option --br -Menv::setenv(LANG=pt_BR) // ポルトガル語 - ブラジル
    option --es -Menv::setenv(LANG=es_ES) // スペイン語
    option --ru -Menv::setenv(LANG=ru_RU) // ロシア語

다음과 같이 사용할 수 있습니다:

    % date -Mi18n --tw
    2017年10月22日 週日 18時00分00秒 JST

`~/.optex.d/optex.rc`에 다음과 같이 자동 로드 모듈을 선언할 수 있습니다:

    autoload -Mi18n --cn --tw --us --fr --de --it --jp --kr --br --es --ru

그러면 모듈 옵션 없이 사용할 수 있습니다. 이 경우 옵션 `--ru`가 `-Mi18n --ru`로 자동 대체됩니다.

    % date --ru
    воскресенье, 22 октября 2017 г. 18:00:00 (JST)

모듈 `i18n`은 [Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n)으로 구현되어 이 배포에 포함되어 있습니다. 따라서 추가 설치 없이 위와 같이 사용할 수 있습니다.

모듈은 `__DATA__` 섹션에서 `builtin` 지시어를 사용하여 기본 제공 옵션을 정의할 수도 있습니다. 기본 제공 옵션은 [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong)에 의해 처리되며 대상 명령어 이름 앞에 지정해야 합니다. 예를 들어

    optex -Mxform --xform-visible=2 cat file

여기서 `--xform-visible`은 `xform` 모듈에 정의된 기본 제공 옵션입니다.

# STANDARD MODULES

표준 모듈은 `앱::옵텍스`에 설치되며, `앱::옵텍스` 접두사를 붙이거나 붙이지 않고 주소 지정이 가능합니다.

- -M**help**

    사용 가능한 옵션 목록을 인쇄합니다. 옵션 이름이 대체 양식 또는 정의된 경우 도움말 메시지와 함께 인쇄됩니다. 도움말 메시지를 생략하려면 **-x** 옵션을 사용합니다.

    옵션 **--맨** 또는 **-h**는 사용 가능한 경우 문서를 인쇄합니다. 옵션 **-l**은 모듈 경로를 인쇄합니다. **-m** 옵션은 모듈 자체를 표시합니다. 다른 모듈 뒤에 사용하면 마지막으로 선언된 모듈에 대한 정보를 인쇄합니다. 다음 명령은 **초** 모듈에 대한 문서를 표시합니다.

        % optex -Mfirst -Msecond -Mhelp --man

- -M**debug**

    디버그 메시지를 인쇄합니다.

- -M**util::argv**

    명령 인수를 조작하는 모듈입니다. 자세한 내용은 [App::optex::util::argv](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Aargv)를 참조하세요.

- -M**util::filter**

    명령 입력/출력 필터를 구현하는 모듈. 자세한 내용은 [App::optex::util::filter](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Afilter)를 참조하세요.

# Getopt::EX MODULES

**옵텍스**는 자체 모듈 외에도 `Getopt::EX` 모듈을 사용할 수 있습니다. 설치된 표준 `Getopt::EX` 모듈은 다음과 같습니다.

- -M**i18n** ([Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n))

    다음을 수행하여 그리스 달력을 표시할 수 있습니다:

        optex -Mi18n cal --gr

# OPTIONS

이 옵션은 심볼릭 링크에서 **옵텍스**가 실행된 경우에는 적용되지 않습니다.

- **--link**, **--ln** \[ _command_ \]

    `~/.optex.d/bin` 디렉터리에 심볼릭 링크를 만듭니다.

- **--unlink**, **--rm** \[ **-f** \] \[ _command_ \]

    `~/.optex.d/bin` 디렉터리에서 심볼릭 링크를 제거합니다.

- **--ls** \[ **-l** \] \[ _command_ \]

    `~/.optex.d/bin` 디렉토리에 심볼릭 링크 파일을 나열합니다.

- **--rc** \[ **-l** \] \[ **-m** \] \[ _command_ \]

    `~/.optex.d` 디렉터리에 rc 파일을 나열합니다.

- **--nop**, **-x** _command_

    옵션 조작을 중지합니다. 그렇지 않으면 전체 경로명을 사용합니다.

- **--**\[**no**\]**module**

    **옵텍스**는 기본적으로 대상 명령의 모듈 옵션(-M)을 처리합니다. 그러나 동일한 옵션을 자체 목적으로 사용하는 명령도 있습니다. 옵션 **--nomodule**은 해당 동작을 비활성화합니다. 다른 옵션 해석은 여전히 유효하며, rc 또는 모듈 파일에서 모듈 옵션을 사용하는 데 아무런 문제가 없습니다.

- **--exit** _status_

    일반적으로 **옵텍스**는 실행된 명령의 상태와 함께 종료됩니다. 이 옵션은 이를 재정의하고 지정된 상태 코드로 강제로 종료합니다.

# CONFIGURATION FILE

시작할 때 **optex**는 TOML 형식으로 작성된 구성 파일 `~/.optex.d/config.toml`을 읽습니다.

## PARAMETERS

- **no-module**

    **옵텍스**가 모듈 옵션 **-M**을 해석하지 않는 명령을 설정합니다. 이 목록에서 대상 명령이 발견되면 **옵텍스**에 옵션 **--no-module**이 주어진 것처럼 실행됩니다.

        no-module = [
            "greple",
            "pgrep",
        ]

- **alias**

    명령 별칭을 설정합니다. 예시:

        [alias]
            pgrep = [ "greple", "-Mperl", "--code" ]
            hello = "echo -n 'hello world!'"

    명령 별칭은 심볼릭 링크와 명령 인수를 통해 호출할 수 있습니다.

- **include**

    기본 구성을 적용하기 전에 추가 TOML 조각을 로드합니다. 문자열 또는 배열을 허용합니다. 각 항목은 리터럴 경로 또는 글로브 패턴일 수 있습니다. 물결표가 확장되고 상대 경로가 포함을 선언한 파일에 대해 확인됩니다. 포함은 깊이 우선으로 처리되며 해시는 재귀적으로 병합되고 배열은 추가되며 스칼라는 라스트 인 윈 시맨틱을 사용합니다. 기본 `config.toml`은 포함된 값을 재정의할 수 있도록 마지막에 적용됩니다.

        include = [
            "~/.optex.d/config.d/*.toml",
            "local.toml",
        ]

    포함 지시어는 중첩될 수 있으며, 주기(자체 글로브 포함)가 감지되어 오류로 보고됩니다.

# FILES AND DIRECTORIES

- `PERLLIB/App/optex`

    시스템 모듈 디렉토리.

- `~/.optex.d/`

    개인 루트 디렉터리.

- `~/.optex.d/config.toml`

    구성 파일.

- `~/.optex.d/default.rc`

    공통 시작 파일.

- `~/.optex.d/`_command_`.rc`

    _명령_의 시작 파일.

- `~/.optex.d/`_command_`/`

    _명령_의 모듈 디렉터리.

- `~/.optex.d/`_command_`/default.pm`

    _명령_의 기본 모듈.

- `~/.optex.d/bin`

    심볼릭 링크를 저장할 기본 디렉토리.

    반드시 필요한 것은 아니지만 **옵텍스**에 대한 심볼릭 링크를 포함하는 특수 디렉터리를 만들어 명령 검색 경로에 배치하는 것이 좋습니다. 그러면 경로에서 쉽게 추가/제거하거나 심볼릭 링크를 생성/제거할 수 있습니다.

# ENVIRONMENT

- OPTEX\_ROOT

    기본 루트 디렉토리 `~/.optex.d` 재정의.

- OPTEX\_CONFIG

    기본 구성 파일 `OPTEX_ROOT/config.toml`을 재정의합니다.

- OPTEX\_MODULE\_PATH

    모듈 경로를 콜론(`:`)으로 구분하여 설정합니다. 표준 경로 앞에 삽입됩니다.

- OPTEX\_BINDIR

    기본 심볼릭 링크 디렉토리 `OPTEX_ROOT/bin`을 재정의합니다.

# SEE ALSO

[Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX), [Getopt::EX::Loader](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3ALoader), [Getopt::EX::Module](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3AModule)

[App::optex::textconv](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Atextconv)

[App::optex::xform](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Axform)

# AUTHOR

Kazumasa Utashiro

# LICENSE

You can redistribute it and/or modify it under the same terms
as Perl itself.

Copyright ©︎ 2017-2025 Kazumasa Utashiro
