# NAME

optex - 汎用コマンド・オプション・ラッパー

# VERSION

Version 1.00

# SYNOPSIS

**optex** _command_ \[ **-M**_module_ \] ...

または _command_ -> **optex** シンボリックリンク、または

**optex** _options_ \[ -l | -m \] ...

    --link,   --ln  create symlink
    --unlink, --rm  remove symlink
    --ls            list link files
    --rc            list rc files
    --nop, -x       disable option processing
    --[no]module    disable module option on arguments

# DESCRIPTION

**optex**はPerlモジュール[Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX)を利用した汎用コマンドオプション処理ラッパーです。これにより、ユーザはシステム上のあらゆるコマンドに対して独自のオプション・エイリアスを定義し、モジュール形式の拡張性を提供することができます。

対象となるコマンドは引数として与えられます：

    % optex command

または**optex**へのシンボリックリンクファイルとして指定します：

    command -> optex

設定ファイル`~/.optex.d/`_コマンド_`.rc`が存在する場合、実行前に評価され、コマンド引数はそれを使用して前処理されます。

## OPTION ALIASES

`-I[TIMESPEC]`オプションを持たないmacOSの`date`コマンドを思い浮かべてほしい。**optex**を使い、`~/.optex.d/date.rc`ファイルに次のような設定をすることで実装できます。

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

コマンドの検索パスにシンボリックリンク`date -> optex`がある場合は、標準コマンドと同じように使用できますが、サポートされていないオプションがあります。

    % date -Iseconds

共通設定は`~/.optex.d/default.rc`ファイルに保存され、これらのルールは**optex**を介して実行されるすべてのコマンドに適用されます。

実際には、`--iso-8601`オプションはこのように簡単に定義できる：

    option --iso-8601 -I$<shift>

これはほとんどの場合うまくいくが、このように`--iso-8601`オプションだけを先行させると失敗する：

    % date --iso-8601 -u

## COMMAND ALIASES

コマンド・エイリアスは設定ファイルで次のように設定できる：

    [alias]
        pgrep = [ "greple", "-Mperl", "--code" ]

エイリアス名はrcファイルとモジュールディレクトリを見つけるために使われます。上記の例では、`~/.optex.d/pgrep.rc`と`~/.optex.d/pgrep/`が参照されます。

["CONFIGURATION FILE"](#configuration-file)セクションを読んでください。

## MACROS

複雑な文字列はマクロ`define`を使って合成できます。次の例は、テキスト中の母音を数えるawkスクリプトで、ファイル`~/.optex.d/awk.rc`で宣言します。

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

これは次のように使えます：

    % awk --vowels /usr/share/dict/words

複雑なオプションを設定するときは `expand` ディレクティブが便利です。`expand`は`option`とほぼ同じ働きをしますが、ファイルスコープ内でのみ有効で、コマンドラインオプションには使えません。

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

**optex**はモジュール拡張にも対応しています。`date`の例では、モジュールファイルは`~/.optex.d/date/`ディレクトリにあります。もしデフォルトのモジュール`~/.optex.d/date/default.pm`が存在すれば、実行の度に自動的にロードされます。

これは通常のPerlモジュールなので、パッケージ宣言と最後の真値が必要です。この間にどんなPerlのコードを入れてもいいです。例えば、次のプログラムでは、`date`コマンドを実行する前に、環境変数`LANG`を`C`に設定します。

    package default;
    $ENV{LANG} = 'C';
    1;

    % /bin/date
    2017年 10月22日 日曜日 18時00分00秒 JST

    % date
    Sun Oct 22 18:00:00 JST 2017

他のモジュールは`-M`オプションを使ってロードします。他のオプションと異なり、`-M`は引数リストの先頭に置かなければなりません。`~/.optex.d/date/`ディレクトリにあるモジュールファイルは、`date`コマンドでのみ使用されます。`~/.optex.d/`ディレクトリにモジュールを置くと、すべてのコマンドから使用できます。

`Mes`モジュールを使用したい場合は、`~/.optex.d/es.pm`に以下の内容のファイルを作成します。

    package es;
    $ENV{LANG} = 'es_ES';
    1;

    % date -Mes
    domingo, 22 de octubre de 2017, 18:00:00 JST

指定されたモジュールがライブラリパスに見つからなかった場合、**optex**はそのオプションを無視し、直ちに引数処理を停止します。無視されたオプションはターゲットコマンドに渡されます。

モジュールはサブルーチンコールでも使われます。`~/.optex.d/env.pm`モジュールが次のようなものであるとする：

    package env;
    sub setenv {
        while (($a, $b) = splice @_, 0, 2) {
            $ENV{$a} = $b;
        }
    }
    1;

そして、より一般的な方法で使用することができます。次の例では、最初の書式は読みやすいですが、2番目の書式はエスケープする特殊文字がないので、より入力しやすくなっています。

    % date -Menv::setenv(LANG=de_DE) # need shell quote
    % date -Menv::setenv=LANG=de_DE  # alternative format
    So 22 Okt 2017 18:00:00 JST

オプション・エイリアスは、モジュール内のファイル末尾で、特殊リテラル `__DATA__` に続けて宣言することもできます。これを使うと、異なる目的のために複数のオプション・セットを用意することができます。一般的な**i18n**モジュールを考えてみよう：

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

これは次のような使い方ができる：

    % date -Mi18n --tw
    2017年10月22日 週日 18時00分00秒 JST

`~/.optex.d/optex.rc`の中でautoloadモジュールを宣言する：

    autoload -Mi18n --cn --tw --us --fr --de --it --jp --kr --br --es --ru

それから、moduleオプションなしで使用することができます。この場合、オプション`--ru`は自動的に`-Mi18n --ru`に置き換えられます。

    % date --ru
    воскресенье, 22 октября 2017 г. 18:00:00 (JST)

モジュール`i18n`は[Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n)として実装され、本ディストリビューションに含まれています。そのため、追加インストールすることなく、上記のように使用することができます。

# STANDARD MODULES

標準モジュールは`App::optex`にインストールされ、`App::optex`接頭辞の有無にかかわらず対応できます。

- -M**help**

    利用可能なオプションリストを表示します。オプション名は、置換形式、または定義されていればヘルプメッセージとともに表示されます。ヘルプメッセージを省略するには **-x** オプションを使います。

    オプション **--man** または **-h** は、利用可能であればドキュメントを表示します。オプション **-l** はモジュールパスを表示します。オプション **-m** はモジュールそのものを表示します。他のモジュールの後に使われた場合は、最後に宣言されたモジュールに関する情報を表示します。次のコマンドは **second** モジュールに関するドキュメントを表示します。

        optex -Mfirst -Msecond -Mhelp --man

- -M**debug**

    デバッグメッセージを表示します。

- -M**util::argv**

    コマンド引数を操作するモジュール。詳しくは[App::optex::util::argv](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Aargv)を参照してください。

- -M**util::filter**

    コマンド入出力フィルタを実装するモジュール。詳しくは[App::optex::util::filter](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Afilter)を参照してください。

# Getopt::EX MODULES

**optex**は、独自のモジュールに加えて、`Getopt::EX`モジュールを使用することもできます。標準的にインストールされている`Getopt::EX`モジュールは以下のものです。

- -M**i18n** ([Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n))

    以下のようにするとギリシャ暦を表示することができます：

        optex -Mi18n cal --gr

# OPTIONS

これらのオプションは、**optex**がシンボリックリンクから実行された場合には有効ではありません。

- **--link**, **--ln** \[ _command_ \]

    `~/.optex.d/bin`ディレクトリにシンボリックリンクを作成します。

- **--unlink**, **--rm** \[ **-f** \] \[ _command_ \]

    `~/.optex.d/bin`ディレクトリのシンボリックリンクを削除します。

- **--ls** \[ **-l** \] \[ _command_ \]

    `~/.optex.d/bin`ディレクトリのシンボリックリンクファイルをリストします。

- **--rc** \[ **-l** \] \[ **-m** \] \[ _command_ \]

    `~/.optex.d`ディレクトリのrcファイルをリストします。

- **--nop**, **-x** _command_

    オプション操作を停止します。それ以外はフルパス名を使用します。

- **--**\[**no**\]**module**

    **optex**はデフォルトでターゲットコマンドのモジュールオプション(-M)を扱う。しかし、同じオプションを独自の目的で使用するコマンドもあります。**--nomodule** オプションはその動作を無効にします。他のオプションの解釈は有効であり、rcファイルやモジュールファイルでmoduleオプションを使用しても問題はありません。

- **--exit** _status_

    通常、**optex**はコマンドを実行した状態で終了します。このオプションはそれを上書きし、指定したステータスコードで強制終了します。

# CONFIGURATION FILE

**optex**は起動時にTOML形式で書かれた設定ファイル`~/.optex.d/config.toml`を読み込みます。

## PARAMETERS

- **no-module**

    **optex**がモジュールオプション**-M**を解釈しないコマンドを設定します。**optex**がモジュールオプション**--no-module**を解釈しないコマンドを設定します。

        no-module = [
            "greple",
            "pgrep",
        ]

- **alias**

    コマンド・エイリアスを設定します。例

        [alias]
            pgrep = [ "greple", "-Mperl", "--code" ]
            hello = "echo -n 'hello world!'"

    コマンドエイリアスは、シンボリックリンクとコマンド引数から呼び出すことができます。

# FILES AND DIRECTORIES

- `PERLLIB/App/optex`

    システムモジュールディレクトリ

- `~/.optex.d/`

    個人用ルートディレクトリ

- `~/.optex.d/config.toml`

    設定ファイル

- `~/.optex.d/default.rc`

    共通スタートアップファイル

- `~/.optex.d/`_command_`.rc`

    _コマンド_のスタートアップファイル

- `~/.optex.d/`_command_`/`

    _コマンド_のモジュール・ディレクトリ

- `~/.optex.d/`_command_`/default.pm`

    _コマンド_のデフォルトモジュール

- `~/.optex.d/bin`

    シンボリックリンクを格納するデフォルトのディレクトリ。

    これは必要ませんが、**optex**のシンボリックリンクを格納する特別なディレクトリを作り、コマンドの検索パスに置くとよい。そうすれば、パスからの追加/削除やシンボリックリンクの作成/削除が簡単にできます。

# ENVIRONMENT

- OPTEX\_ROOT

    デフォルトのルートディレクトリ`~/.optex.d`を上書きします。

- OPTEX\_CONFIG

    デフォルトの設定ファイル `OPTEX_ROOT/config.toml` を上書きします。

- OPTEX\_MODULE\_PATH

    コロン(`:`)で区切られたモジュールパスを設定します。これらは標準パスの前に挿入されます。

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

Copyright ©︎ 2017-2024 Kazumasa Utashiro
