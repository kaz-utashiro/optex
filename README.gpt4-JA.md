# NAME

optex - 汎用コマンドオプションラッパー

# VERSION

Version 1.02

# SYNOPSIS

**optex** _コマンド_ \[ **-M**_モジュール_ \] ...

または _コマンド_ -> **optex** シンボリックリンク、または

**optex** _オプション_ \[ -l | -m \] ...

    --link,   --ln  create symlink
    --unlink, --rm  remove symlink
    --ls            list link files
    --rc            list rc files
    --nop, -x       disable option processing
    --[no]module    disable module option on arguments

# DESCRIPTION

**optex**はPerlモジュール[Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX)を利用した汎用コマンドオプション処理ラッパーです。ユーザーはシステム上の任意のコマンドに対して自分自身のオプションエイリアスを定義し、モジュールスタイルの拡張性を提供することができます。

対象のコマンドは引数として与えられます：

    % optex command

または**optex**へのシンボリックリンクされたファイルとして：

    command -> optex

設定ファイル`~/.optex.d/`_コマンド_`.rc`が存在する場合、実行前に評価され、その設定を使用してコマンド引数が事前処理されます。

## OPTION ALIASES

macOSの`date`コマンドを考えてみましょう。これには`-I[TIMESPEC]`オプションがありません。**optex**を使用すると、`~/.optex.d/date.rc`ファイルに次の設定を準備することで実装することができます。

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

次のコマンドは期待通りに動作します。

    % optex date -Iseconds

コマンド検索パスに`date -> optex`のシンボリックリンクが見つかった場合、標準コマンドと同じように使用できますが、サポートされていないオプションも使用できます。

    % date -Iseconds

共通の設定は`~/.optex.d/default.rc`ファイルに保存され、それらのルールは**optex**を通じて実行されるすべてのコマンドに適用されます。

実際には、`--iso-8601`オプションはこのように単純に定義することができます：

    option --iso-8601 -I$<shift>

これはほとんどの場合うまく動作しますが、他のオプションの前に単独で`--iso-8601`オプションがある場合には失敗します：

    % date --iso-8601 -u

## COMMAND ALIASES

**optex**のコマンドエイリアスはシェルのエイリアス機能と変わりませんが、ツールやスクリプトからコマンドとして実行できる点、設定ファイルで一括管理できる点が有効です。

コマンドエイリアスは、設定ファイル（`~/.optex.d/config.toml`）にこのように設定できます：

    [alias]
        tc = "optex -Mtextconv"

次のように`tc`から`optex`へのシンボリックリンクを作成できます：

    % optex --ln tc

そして、`$HOME/.optex.d/bin`をあなたの`PATH`環境に含めます。

`textconv`モジュールは、引数として与えられたファイルをプレーンテキストに変換するために使用できます。このように定義すると、Wordファイルは次のように比較できます。

    % tc diff A.docx B.docx

エイリアス名はrcファイルとモジュールディレクトリを見つけるために使用されます。上記の例では、`~/.optex.d/tc.rc`と`~/.optex.d/tc/`が参照されます。

設定ファイルにシェルスクリプトを書くことも可能です。次の例は、Cシェルの`repeat`コマンドを実装しています。

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

["CONFIGURATION FILE"](#configuration-file)セクションを読んでください。

## MACROS

マクロ`define`を使用して複雑な文字列を構成することができます。次の例は、テキスト内の母音を数えるawkスクリプトで、`~/.optex.d/awk.rc`ファイルに宣言されます。

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

これは次のように使用できます：

    % awk --vowels /usr/share/dict/words

複雑なオプションを設定する場合、`expand`ディレクティブが便利です。`expand`は`option`とほぼ同じように動作しますが、ファイルスコープ内でのみ有効であり、コマンドラインオプションでは使用できません。

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

**optex**はモジュール拡張もサポートしています。`date`の例では、モジュールファイルは`~/.optex.d/date/`ディレクトリにあります。デフォルトモジュール`~/.optex.d/date/default.pm`が存在する場合、実行のたびに自動的にロードされます。

これは通常のPerlモジュールなので、パッケージ宣言と最後の真値が必要です。その間には、任意のPerlコードを入れることができます。例えば、次のプログラムは`date`コマンドを実行する前に環境変数`LANG`を`C`に設定します。

    package default;
    $ENV{LANG} = 'C';
    1;

    % /bin/date
    2017年 10月22日 日曜日 18時00分00秒 JST

    % date
    Sun Oct 22 18:00:00 JST 2017

他のモジュールは`-M`オプションを使用してロードされます。他のオプションとは異なり、`-M`は引数リストの最初に置かなければなりません。`~/.optex.d/date/`ディレクトリのモジュールファイルは`date`コマンド専用です。モジュールが`~/.optex.d/`ディレクトリに配置されている場合、すべてのコマンドから使用できます。

`-Mes`モジュールを使用したい場合は、次の内容で`~/.optex.d/es.pm`ファイルを作成します。

    package es;
    $ENV{LANG} = 'es_ES';
    1;

    % date -Mes
    domingo, 22 de octubre de 2017, 18:00:00 JST

指定されたモジュールがライブラリパスに見つからない場合、**optex**はオプションを無視し、直ちに引数処理を停止します。無視されたオプションは対象のコマンドにそのまま渡されます。

モジュールはサブルーチンコールと共に使用されます。例えば `~/.optex.d/env.pm` モジュールは以下のようになります：

    package env;
    sub setenv {
        while (($a, $b) = splice @_, 0, 2) {
            $ENV{$a} = $b;
        }
    }
    1;

それから、より一般的な方法で使用することができます。次の例では、最初のフォーマットは読みやすいですが、特殊文字をエスケープする必要がないため、2番目のものの方がタイプしやすいです。

    % date -Menv::setenv(LANG=de_DE) # need shell quote
    % date -Menv::setenv=LANG=de_DE  # alternative format
    So 22 Okt 2017 18:00:00 JST

オプションエイリアスもモジュールの最後に、特別なリテラル `__DATA__` の後に宣言することができます。これを使用して、異なる目的のための複数のオプションセットを準備することができます。一般的な **i18n** モジュールについて考えてみてください：

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

これは以下のように使用することができます：

    % date -Mi18n --tw
    2017年10月22日 週日 18時00分00秒 JST

`~/.optex.d/optex.rc` にオートロードモジュールを宣言することができます：

    autoload -Mi18n --cn --tw --us --fr --de --it --jp --kr --br --es --ru

その後、モジュールオプションなしでそれらを使用することができます。この場合、オプション `--ru` は自動的に `-Mi18n --ru` に置き換えられます。

    % date --ru
    воскресенье, 22 октября 2017 г. 18:00:00 (JST)

モジュール `i18n` は [Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n) として実装されており、この配布に含まれています。したがって、追加のインストールなしで上記のように使用することができます。

# STANDARD MODULES

標準モジュールは `App::optex` にインストールされており、`App::optex` プレフィックスの有無にかかわらずアドレス指定することができます。

- -M**help**

    利用可能なオプションリストを表示します。オプション名は置換形式で印刷されるか、定義されていればヘルプメッセージが印刷されます。ヘルプメッセージを省略するには **-x** オプションを使用します。

    オプション **--man** または **-h** は、利用可能であればドキュメントを印刷します。オプション **-l** はモジュールパスを印刷します。オプション **-m** はモジュール自体を表示します。他のモジュールの後に使用された場合、最後に宣言されたモジュールについての情報を印刷します。次のコマンドは **second** モジュールについてのドキュメントを表示します。

        % optex -Mfirst -Msecond -Mhelp --man

- -M**debug**

    デバッグメッセージを印刷します。

- -M**util::argv**

    コマンド引数を操作するモジュール。詳細については [App::optex::util::argv](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Aargv) を参照してください。

- -M**util::filter**

    コマンド入出力フィルタを実装するモジュール。詳細については [App::optex::util::filter](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Afilter) を参照してください。

# Getopt::EX MODULES

独自のモジュールに加えて、**optex** は `Getopt::EX` モジュールも使用することができます。インストールされている標準の `Getopt::EX` モジュールはこれらです。

- -M**i18n** ([Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n))

    以下の手順でギリシャ暦を表示することができます：

        optex -Mi18n cal --gr

# OPTIONS

これらのオプションは、**optex** がシンボリックリンクから実行された場合には効果がありません。

- **--link**, **--ln** \[ _command_ \]

    `~/.optex.d/bin` ディレクトリにシンボリックリンクを作成します。

- **--unlink**, **--rm** \[ **-f** \] \[ _command_ \]

    `~/.optex.d/bin` ディレクトリのシンボリックリンクを削除します。

- **--ls** \[ **-l** \] \[ _command_ \]

    `~/.optex.d/bin` ディレクトリのシンボリックリンクファイルをリストします。

- **--rc** \[ **-l** \] \[ **-m** \] \[ _command_ \]

    `~/.optex.d` ディレクトリの rc ファイルをリストします。

- **--nop**, **-x** _command_

    オプション操作を停止します。それ以外の場合は完全なパス名を使用してください。

- **--**\[**no**\]**module**

    **optex** はデフォルトで対象コマンドのモジュールオプション (-M) を扱います。しかし、同じオプションを独自の目的で使用するコマンドもあります。オプション **--nomodule** はその動作を無効にします。他のオプション解釈はまだ有効であり、rc ファイルやモジュールファイルでモジュールオプションを使用することに問題はありません。

- **--exit** _status_

    通常 **optex** は実行されたコマンドのステータスで終了します。このオプションはそれをオーバーライドし、指定されたステータスコードで強制終了します。

# CONFIGURATION FILE

起動時に、**optex** は TOML 形式で書かれることを想定している設定ファイル `~/.optex.d/config.toml` を読み込みます。

## PARAMETERS

- **no-module**

    **optex** がモジュールオプション **-M** を解釈しないコマンドを設定します。対象コマンドがこのリストに見つかった場合、**optex** にオプション **--no-module** が与えられたかのように実行されます。

        no-module = [
            "greple",
            "pgrep",
        ]

- **alias**

    コマンドエイリアスを設定します。例：

        [alias]
            pgrep = [ "greple", "-Mperl", "--code" ]
            hello = "echo -n 'hello world!'"

    コマンドエイリアスは、シンボリックリンクとコマンド引数のいずれからも呼び出すことができます。

# FILES AND DIRECTORIES

- `PERLLIB/App/optex`

    システムモジュールディレクトリ。

- `~/.optex.d/`

    個人のルートディレクトリ。

- `~/.optex.d/config.toml`

    設定ファイル。

- `~/.optex.d/default.rc`

    共通のスタートアップファイル。

- `~/.optex.d/`_command_`.rc`

    _コマンド_用のスタートアップファイル。

- `~/.optex.d/`_command_`/`

    _コマンド_用のモジュールディレクトリ。

- `~/.optex.d/`_command_`/default.pm`

    _コマンド_のデフォルトモジュール。

- `~/.optex.d/bin`

    シンボリックリンクを保存するデフォルトディレクトリ。

    これは必須ではありませんが、**optex**用のシンボリックリンクを含む特別なディレクトリを作成し、コマンド検索パスに配置すると良いと思われます。そうすることで、パスの追加/削除やシンボリックリンクの作成/削除を簡単に行うことができます。

# ENVIRONMENT

- OPTEX\_ROOT

    デフォルトのルートディレクトリ`~/.optex.d`を上書きします。

- OPTEX\_CONFIG

    デフォルトの設定ファイル`OPTEX_ROOT/config.toml`を上書きします。

- OPTEX\_MODULE\_PATH

    コロン(`:`)で区切られたモジュールパスを設定します。これらは標準パスの前に挿入されます。

- OPTEX\_BINDIR

    デフォルトのシンボリックリンクディレクトリ`OPTEX_ROOT/bin`を上書きします。

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
