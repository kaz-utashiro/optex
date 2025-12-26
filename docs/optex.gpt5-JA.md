# NAME

optex - 汎用コマンドオプションラッパー

# VERSION

Version 1.05

# SYNOPSIS

**optex** _command_ \[ **-M**_module_ \] ...

または _command_ -> **optex** のシンボリックリンク、あるいは

**optex** _options_ \[ -l | -m \] ...

    --link,   --ln  create symlink
    --unlink, --rm  remove symlink
    --ls            list link files
    --rc            list rc files
    --nop, -x       disable option processing
    --[no]module    disable module option on arguments

# DESCRIPTION

**optex** は Perl モジュール [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX) を利用した汎用のコマンドオプション処理ラッパーです。ユーザーはシステム上のあらゆるコマンドに対して独自のオプションエイリアスを定義でき、モジュール式の拡張性を提供します。

対象コマンドは引数として与えます:

    % optex command

または **optex** へのシンボリックリンクされたファイルとして:

    command -> optex

設定ファイル `~/.optex.d/`_command_`.rc` が存在する場合は、実行前に評価され、それを用いてコマンド引数が前処理されます。

## OPTION ALIASES

macOS の `date` コマンドには `-I[TIMESPEC]` オプションがありません。**optex** を使えば、`~/.optex.d/date.rc` に以下の設定を用意することで実装できます。

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

その後、次のコマンドは期待どおり動作します。

    % optex date -Iseconds

コマンド検索パスに `date -> optex` のシンボリックリンクが見つかれば、未対応のオプション付きでも標準コマンドと同様に使用できます。

    % date -Iseconds

共通設定は `~/.optex.d/default.rc` に保存され、**optex** を介して実行されるすべてのコマンドにそのルールが適用されます。

実際、`--iso-8601` オプションは次のようにより簡単に定義できます:

    option --iso-8601 -I$<shift>

これはほとんどの場合うまく動作しますが、次のように他のオプションに先行して単独の `--iso-8601` オプションだけがある場合は失敗します:

    % date --iso-8601 -u

## COMMAND ALIASES

**optex** のコマンドエイリアスはシェルの alias 機能と変わりませんが、ツールやスクリプトからコマンドとして実行でき、設定ファイルで一元管理できる点が有効です。

コマンドエイリアスは次のように設定ファイル (`~/.optex.d/config.toml`) で設定できます:

    [alias]
        tc = "optex -Mtextconv"

次のように `tc` から `optex` へのシンボリックリンクを作成できます:

    % optex --ln tc

そして `$HOME/.optex.d/bin` を `PATH` 環境に含めてください。

`textconv` モジュールは引数として与えたファイルをプレーンテキストに変換するために使用できます。このように定義すれば、Word ファイルを次のように比較できます。

    % tc diff A.docx B.docx

エイリアス名は rc ファイルとモジュールディレクトリの検索に使用されます。上記の例では `~/.optex.d/tc.rc` と `~/.optex.d/tc/` が参照されます。

設定ファイルにシェルスクリプトを書くことも可能です。次の例は C シェルの `repeat` コマンドの実装です。

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

["CONFIGURATION FILE"](#configuration-file) セクションを参照してください。

## MACROS

マクロ `define` を使って複雑な文字列を構成できます。次の例は `~/.optex.d/awk.rc` に記述する、テキスト中の母音を数える awk スクリプトです。

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

これは次のように使用できます:

    % awk --vowels /usr/share/dict/words

複雑なオプションを設定する場合、`expand` ディレクティブが有用です。`expand` は `option` とほぼ同様に動作しますが、ファイルスコープ内でのみ有効で、コマンドラインオプションとしては利用できません。

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

**optex** はモジュール拡張にも対応しています。`date` の例では、モジュールファイルは `~/.optex.d/date/` ディレクトリにあります。デフォルトモジュール `~/.optex.d/date/default.pm` が存在すれば、実行のたびに自動的に読み込まれます。

これは通常のPerlモジュールなので、package宣言と最後の真値が必要です。これらの間には、あらゆる種類のPerlコードを記述できます。たとえば、次のプログラムは、`date` コマンドを実行する前に、環境変数 `LANG` を `C` に設定します。

    package default;
    $ENV{LANG} = 'C';
    1;

    % /bin/date
    2017年 10月22日 日曜日 18時00分00秒 JST

    % date
    Sun Oct 22 18:00:00 JST 2017

他のモジュールは `-M` オプションで読み込みます。他のオプションと異なり、`-M` は引数リストの先頭に置かなければなりません。`~/.optex.d/date/` ディレクトリ内のモジュールファイルは `date` コマンドに対してのみ使用されます。モジュールが `~/.optex.d/` ディレクトリに置かれている場合は、すべてのコマンドから使用できます。

`-Mes` モジュールを使いたい場合は、次の内容で `~/.optex.d/es.pm` ファイルを作成してください。

    package es;
    $ENV{LANG} = 'es_ES';
    1;

    % date -Mes
    domingo, 22 de octubre de 2017, 18:00:00 JST

指定されたモジュールがライブラリパスで見つからない場合、**optex** はそのオプションを無視し、即座に引数処理を停止します。無視されたオプションは対象コマンドへそのまま渡されます。

モジュールはサブルーチン呼び出しでも使用されます。`~/.optex.d/env.pm` モジュールが次のようだとします:

    package env;
    sub setenv {
        while (($a, $b) = splice @_, 0, 2) {
            $ENV{$a} = $b;
        }
    }
    1;

すると、より汎用的に使えるようになります。次の例では、最初の形式は読みやすく、2つ目はエスケープすべき特殊文字がないため入力しやすい形式です。

    % date -Menv::setenv(LANG=de_DE) # need shell quote
    % date -Menv::setenv=LANG=de_DE  # alternative format
    So 22 Okt 2017 18:00:00 JST

オプションのエイリアスは、ファイル末尾の特別なリテラル `__DATA__` に続けてモジュール内で宣言できます。これを使うと、用途に応じて複数のオプションセットを用意できます。汎用的な **i18n** モジュールを考えてみましょう:

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

これは次のように使えます:

    % date -Mi18n --tw
    2017年10月22日 週日 18時00分00秒 JST

`~/.optex.d/optex.rc` で自動読み込みモジュールを次のように宣言できます:

    autoload -Mi18n --cn --tw --us --fr --de --it --jp --kr --br --es --ru

するとモジュールオプションなしで使えるようになります。この場合、オプション `--ru` は自動的に `-Mi18n --ru` に置き換えられます。

    % date --ru
    воскресенье, 22 октября 2017 г. 18:00:00 (JST)

モジュール `i18n` は [Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n) として実装され、この配布物に含まれています。したがって、追加インストールなしで上記のように使用できます。

モジュールは `__DATA__` セクション内の `builtin` ディレクティブを使って組み込みオプションも定義できます。組み込みオプションは [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) によって処理され、対象コマンド名の前に指定しなければなりません。例:

    optex -Mxform --xform-visible=2 cat file

ここで `--xform-visible` は `xform` モジュールで定義された組み込みオプションです。

# STANDARD MODULES

標準モジュールは `App::optex` にインストールされており、`App::optex` プレフィックスあり／なしのどちらでも指定できます。

- -M**help**

    利用可能なオプション一覧を表示します。オプション名は置換形、または定義されていればヘルプメッセージとともに出力されます。ヘルプメッセージを省くには **-x** オプションを使用します。

    オプション **--man** または **-h** は、可能であればドキュメントを表示します。オプション **-l** はモジュールのパスを表示します。オプション **-m** はモジュール本体を表示します。他のモジュール指定の後に使うと、最後に宣言されたモジュールに関する情報を表示します。次のコマンドは **second** モジュールに関するドキュメントを表示します。

        % optex -Mfirst -Msecond -Mhelp --man

- -M**debug**

    デバッグメッセージを出力します。

- -M**util::argv**

    コマンド引数を操作するモジュール。詳細は [App::optex::util::argv](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Aargv) を参照してください。

- -M**util::filter**

    コマンドの入出力フィルタを実装するモジュール。詳細は [App::optex::util::filter](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Afilter) を参照してください。

# Getopt::EX MODULES

独自のモジュールに加えて、**optex** は `Getopt::EX` のモジュールも使用できます。標準の `Getopt::EX` モジュールとしては次のものがインストールされています。

- -M**i18n** ([Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n))

    次のようにすると、ギリシャ暦を表示できます:

        optex -Mi18n cal --gr

# OPTIONS

これらのオプションは、**optex** がシンボリックリンクから実行された場合は有効ではありません。

- **--link**, **--ln** \[ _command_ \]

    `~/.optex.d/bin` ディレクトリにシンボリックリンクを作成します。

- **--unlink**, **--rm** \[ **-f** \] \[ _command_ \]

    `~/.optex.d/bin` ディレクトリのシンボリックリンクを削除します。

- **--ls** \[ **-l** \] \[ _command_ \]

    `~/.optex.d/bin` ディレクトリのシンボリックリンクファイルを一覧表示します。

- **--rc** \[ **-l** \] \[ **-m** \] \[ _command_ \]

    `~/.optex.d` ディレクトリの rc ファイルを一覧表示します。

- **--nop**, **-x** _command_

    オプション操作を停止します。そうでない場合はフルパス名を使用してください。

- **--**\[**no**\]**module**

    **optex** はデフォルトで対象コマンドに対するモジュールオプション (-M) を扱います。しかし、同じオプションを独自の目的で使用するコマンドもあります。オプション **--nomodule** はその動作を無効化します。他のオプション解釈は引き続き有効で、rc やモジュールファイルでモジュールオプションを使用しても問題ありません。

- **--exit** _status_

    通常 **optex** は実行したコマンドの終了ステータスで終了します。このオプションはそれを上書きし、指定したステータスコードで終了するように強制します。

# CONFIGURATION FILE

起動時に、**optex** は TOML 形式で記述される想定の設定ファイル `~/.optex.d/config.toml` を読み込みます。

## PARAMETERS

- **no-module**

    **optex** がモジュールオプション **-M** を解釈しないコマンドを設定します。対象コマンドがこのリストに見つかった場合、**optex** に **--no-module** オプションが与えられたかのように実行されます。

        no-module = [
            "greple",
            "pgrep",
        ]

- **alias**

    コマンドエイリアスを設定します。例:

        [alias]
            pgrep = [ "greple", "-Mperl", "--code" ]
            hello = "echo -n 'hello world!'"

    コマンドエイリアスはシンボリックリンクからでもコマンド引数からでも呼び出せます。

- **include**

    メインの設定を適用する前に、追加の TOML フラグメントを読み込みます。文字列または配列を受け付けます。各エントリはリテラルのパスまたはグロブパターンにできます。チルダは展開され、相対パスは include を宣言したファイルを基準に解決されます。include は深さ優先で処理されます。ハッシュは再帰的にマージされ、配列は末尾に追加され、スカラーは後勝ちのセマンティクスを使用します。メインの `config.toml` は最後に適用されるため、インクルードされた値を上書きできます。

        include = [
            "~/.optex.d/config.d/*.toml",
            "local.toml",
        ]

    include ディレクティブは入れ子にできます。サイクル（自己グロブを含む）は検出され、エラーとして報告されます。

# FILES AND DIRECTORIES

- `PERLLIB/App/optex`

    システムモジュールディレクトリ。

- `~/.optex.d/`

    個人用ルートディレクトリ。

- `~/.optex.d/config.toml`

    設定ファイル。

- `~/.optex.d/default.rc`

    共通の起動ファイル。

- `~/.optex.d/`_command_`.rc`

    _command_ 用の起動ファイル。

- `~/.optex.d/`_command_`/`

    _command_ 用のモジュールディレクトリ。

- `~/.optex.d/`_command_`/default.pm`

    _command_ 用のデフォルトモジュール。

- `~/.optex.d/bin`

    シンボリックリンクを保存するデフォルトのディレクトリ。

    必須ではありませんが、**optex** 用のシンボリックリンクを収める特別なディレクトリを作成し、コマンド検索パスに配置するのはよい考えです。そうすれば、パスへの追加/削除やシンボリックリンクの作成/削除が容易になります。

# ENVIRONMENT

- OPTEX\_ROOT

    デフォルトのルートディレクトリ `~/.optex.d` を上書きします。

- OPTEX\_CONFIG

    デフォルトの設定ファイル `OPTEX_ROOT/config.toml` を上書きします。

- OPTEX\_MODULE\_PATH

    コロン (`:`) 区切りでモジュールパスを設定します。これらは標準パスの前に挿入されます。

- OPTEX\_BINDIR

    デフォルトのシンボリックリンクディレクトリ `OPTEX_ROOT/bin` を上書きします。

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
