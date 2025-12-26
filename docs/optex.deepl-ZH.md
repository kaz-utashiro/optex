# NAME

optex - 通用命令选项包装器

# VERSION

Version 1.05

# SYNOPSIS

**optex** _command_ \[ **-M**_module_ \] ...

或 _command_ -> **optex** 符号链接，或

**optex** _options_ \[ -l | -m \] ...

    --link,   --ln  create symlink
    --unlink, --rm  remove symlink
    --ls            list link files
    --rc            list rc files
    --nop, -x       disable option processing
    --[no]module    disable module option on arguments

# DESCRIPTION

**optex** 是一个利用 Perl 模块 [Getopt::EX](https://metacpan.org/pod/Getopt%3A%3AEX) 的通用命令选项处理包装器。它允许用户为系统中的任何命令定义自己的选项别名，并提供模块风格的可扩展性。

目标命令作为参数给出：

    % optex command

或 **optex** 的符号链接文件：

    command -> optex

如果存在配置文件 `~/.optex.d/`_command_`.rc`，则会在执行前对其进行评估，并使用该文件对命令参数进行预处理。

## OPTION ALIASES

想想 macOS 的 `date` 命令，它没有 `-I[TIMESPEC]` 选项。使用 **optex**，可以通过在 `~/.optex.d/date.rc` 文件中进行以下设置来实现这些功能。

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

然后，下一条命令就会按预期运行。

    % optex date -Iseconds

如果在命令搜索路径中找到符号链接 `date -> optex`，则可以使用与标准命令相同的命令，但使用不支持的选项。

    % date -Iseconds

常用配置保存在 `~/.optex.d/default.rc` 文件中，这些规则将应用于通过 **optex** 执行的所有命令。

实际上，`--iso-8601` 选项可以定义得更简单：

    option --iso-8601 -I$<shift>

几乎每次都能正常工作，但如果只有 `--iso-8601` 选项在其他选项之前，则会出现类似故障：

    % date --iso-8601 -u

## COMMAND ALIASES

**optex** 的命令别名与 shell 的别名功能并无不同，但它的高效之处在于可以作为工具或脚本的命令执行，并可在配置文件中进行统一管理。

命令别名可以像这样在配置文件（`~/.optex.d/config.toml`）中设置：

    [alias]
        tc = "optex -Mtextconv"

可以像这样从 `tc` 建立符号链接到 `optex`：

    % optex --ln tc

并在 `PATH` 环境中包含 `$HOME/.optex.d/bin`。

`textconv` 模块可用于将作为参数给定的文件转换为纯文本。以这种方式定义的 Word 文件可按如下方式进行比较。

    % tc diff A.docx B.docx

别名用于查找 rc 文件和模块目录。在上例中，将引用 `~/.optex.d/tc.rc` 和 `~/.optex.d/tc/`。

也可以在配置文件中编写 shell 脚本。下面的示例实现了 C-shell `repeat` 命令。

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

请阅读 ["CONFIGURATION FILE"](#configuration-file) 部分。

## MACROS

使用宏 `define` 可以组成复杂的字符串。下一个例子是在文件 `~/.optex.d/awk.rc` 中声明的计算文本中元音的 awk 脚本。

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

可以这样使用

    % awk --vowels /usr/share/dict/words

在设置复杂选项时，`expand` 指令非常有用。`expand` 的作用与 `option` 几乎相同，但只在文件范围内有效，不适用于命令行选项。

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

**optex** 还支持模块扩展。以 `date` 为例，模块文件位于 `~/.optex.d/date/` 目录下。如果存在默认模块 `~/.optex.d/date/default.pm`，则每次执行时都会自动加载该模块。

这是一个普通的 Perl 模块，因此包声明和最终 true 值是必要的。在它们之间，可以放入任何类型的 Perl 代码。例如，下一个程序在执行 `date` 命令前将环境变量 `LANG` 设为 `C`。

    package default;
    $ENV{LANG} = 'C';
    1;

    % /bin/date
    2017年 10月22日 日曜日 18時00分00秒 JST

    % date
    Sun Oct 22 18:00:00 JST 2017

其他模块使用 `-M` 选项加载。与其他选项不同，`-M` 必须放在参数列表的开头。`~/.optex.d/date/` 目录中的模块文件只用于 `date` 命令。如果模块放在 `~/.optex.d/` 目录下，则所有命令都可以使用它。

如果要使用 `-Mes` 模块，请在 `~/.optex.d/es.pm` 文件中加入以下内容。

    package es;
    $ENV{LANG} = 'es_ES';
    1;

    % date -Mes
    domingo, 22 de octubre de 2017, 18:00:00 JST

如果在库路径中找不到指定的模块，**optex** 将忽略该选项并立即停止参数处理。忽略的选项将传递给目标命令。

模块也用于子程序调用。假设 `~/.optex.d/env.pm` 模块看起来像这样：

    package env;
    sub setenv {
        while (($a, $b) = splice @_, 0, 2) {
            $ENV{$a} = $b;
        }
    }
    1;

那么它可以以更通用的方式使用。在下例中，第一种格式易于阅读，但第二种格式更易于键入，因为它没有需要转义的特殊字符。

    % date -Menv::setenv(LANG=de_DE) # need shell quote
    % date -Menv::setenv=LANG=de_DE  # alternative format
    So 22 Okt 2017 18:00:00 JST

选项别名也可以在模块中声明，位于文件末尾，紧跟特殊字面 `__DATA__`。利用这一点，你可以为不同目的准备多组选项。想想通用的 **i18n** 模块：

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

使用方法如下：

    % date -Mi18n --tw
    2017年10月22日 週日 18時00分00秒 JST

可以在 `~/.optex.d/optex.rc` 中声明自动加载模块：

    autoload -Mi18n --cn --tw --us --fr --de --it --jp --kr --br --es --ru

然后就可以在没有模块选项的情况下使用它们了。在这种情况下，选项 `--ru` 会被 `-Mi18n --ru` 自动替换。

    % date --ru
    воскресенье, 22 октября 2017 г. 18:00:00 (JST)

模块 `i18n` 作为 [Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n) 实现，并包含在此发行版中。因此，无需额外安装，即可如上使用。

模块还可以使用 `__DATA__` 部分的 `builtin` 指令定义内置选项。内置选项由 [Getopt::Long](https://metacpan.org/pod/Getopt%3A%3ALong) 处理，必须在目标命令名之前指定。例如

    optex -Mxform --xform-visible=2 cat file

这里的 `--xform-visible` 是 `xform` 模块中定义的内置选项。

# STANDARD MODULES

标准模块安装在 `App::optex`，可以使用或不使用 `App::optex`前缀。

- -M**help**

    打印可用选项列表。选项名称与替换形式一起打印，如果已定义，则打印帮助信息。使用 **-x** 选项可省略帮助信息。

    选项 **--man** 或 **-h** 将打印文件（如果有）。选项 **-l** 将打印模块路径。选项 **-m** 将显示模块本身。在其他模块之后使用时，将打印最后声明模块的信息。下一条命令将显示 **second** 模块的文档。

        % optex -Mfirst -Msecond -Mhelp --man

- -M**debug**

    打印调试信息。

- -M**util::argv**

    操作命令参数的模块。详见 [App::optex::util::argv](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Aargv)。

- -M**util::filter**

    实现命令输入/输出过滤器的模块。详见 [App::optex::util::filter](https://metacpan.org/pod/App%3A%3Aoptex%3A%3Autil%3A%3Afilter)。

# Getopt::EX MODULES

除自身模块外，**optex** 还可以使用 `Getopt::EX` 模块。已安装的标准 `Getopt::EX` 模块如下。

- -M**i18n** ([Getopt::EX::i18n](https://metacpan.org/pod/Getopt%3A%3AEX%3A%3Ai18n))

    您可以通过以下操作显示希腊日历：

        optex -Mi18n cal --gr

# OPTIONS

从符号链接执行 **optex** 时，这些选项无效。

- **--link**, **--ln** \[ _command_ \]

    在 `~/.optex.d/bin` 目录中创建符号链接。

- **--unlink**, **--rm** \[ **-f** \] \[ _command_ \]

    删除 `~/.optex.d/bin` 目录中的符号链接。

- **--ls** \[ **-l** \] \[ _command_ \]

    列出 `~/.optex.d/bin` 目录中的符号链接文件。

- **--rc** \[ **-l** \] \[ **-m** \] \[ _command_ \]

    列出 `~/.optex.d/bin` 目录中的 rc 文件。

- **--nop**, **-x** _command_

    停止选项操作。否则使用完整路径名。

- **--**\[**no**\]**module**

    **optex** 默认处理目标命令的模块选项 (-M)。不过，有一条命令也使用相同的选项。选项 **--nomodule** 会禁用这种行为。其他选项的解释仍然有效，在 rc 或模块文件中使用模块选项也没有问题。

- **--exit** _status_

    通常 **optex** 会以已执行命令的状态退出。该选项会覆盖它，强制以指定的状态代码退出。

# CONFIGURATION FILE

启动时，**optex** 会读取配置文件 `~/.optex.d/config.toml`，该文件应为 TOML 格式。

## PARAMETERS

- **no-module**

    设置 **optex** 不解释模块选项 **-M** 的命令。如果在此列表中找到目标命令，就会像给 **optex** 提供选项 **--no-module** 一样执行该命令。

        no-module = [
            "greple",
            "pgrep",
        ]

- **alias**

    设置命令别名。例如

        [alias]
            pgrep = [ "greple", "-Mperl", "--code" ]
            hello = "echo -n 'hello world!'"

    命令别名可通过符号链接和命令参数调用。

- **include**

    在应用主配置之前加载额外的 TOML 片段。接受字符串或数组。每个条目可以是字面路径或 glob 模式。Tilde 会被展开，相对路径会根据声明包含的文件进行解析。包含是深度优先处理的；哈希值递归合并，数组追加，标量使用后进先出语义。主 `config.toml` 最后应用，因此可以覆盖包含值。

        include = [
            "~/.optex.d/config.d/*.toml",
            "local.toml",
        ]

    包含指令可以嵌套；循环（包括自球）会被检测到并作为错误报告。

# FILES AND DIRECTORIES

- `PERLLIB/App/optex`

    系统模块目录。

- `~/.optex.d/`

    个人根目录。

- `~/.optex.d/config.toml`

    配置文件。

- `~/.optex.d/default.rc`

    常用启动文件。

- `~/.optex.d/`_command_`.rc`

    _command_ 的启动文件。

- `~/.optex.d/`_command_`/`

    _command_ 的模块目录。

- `~/.optex.d/`_command_`/default.pm`

    _command_ 的默认模块。

- `~/.optex.d/bin`

    存储符号链接的默认目录。

    这并非必要，但将 **optex** 设置为包含符号链接的特殊目录，并将其置于命令搜索路径中似乎是个好主意。这样你就可以很容易地从路径中添加/删除它，或创建/删除符号链接。

# ENVIRONMENT

- OPTEX\_ROOT

    覆盖默认根目录 `~/.optex.d`。

- OPTEX\_CONFIG

    覆盖默认配置文件 `OPTEX_ROOT/config.toml`。

- OPTEX\_MODULE\_PATH

    设置以冒号 (`:`) 分隔的模块路径。这些路径将插入标准路径之前。

- OPTEX\_BINDIR

    覆盖默认的符号链接目录 `OPTEX_ROOT/bin`。

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
