import std.stdio;
import std.file;
import std.algorithm;
import std.range;
import std.string;
import std.conv;
import std.array;

class Clippings
{
    Clipping[string] clippings;
    auto add(Clipping clipping)
    {
        string h = clipping.toString;
        if (h !in clippings)
        {
            clippings[h] = clipping;
        }
        return this;
    }

    auto remove(Clipping clipping)
    {
        string h = clipping.toString;
        if (h in clippings)
        {
            clippings.remove(h);
        }
        return this;
    }

    auto assignNotesToClippings()
    {
        Clipping[] toRemove = [];
        foreach (note; clippings.values.dup)
        {
            if (note.type == "note")
            {
                foreach (clipping; clippings.values)
                {
                    if ((note != clipping) && (note.book == clipping.book))
                    {
                        if (note.location.intersects(clipping.location))
                        {
                            "Assigning %s to %s".format(note, clipping).writeln;
                            toRemove ~= note;
                            clipping.add(note);
                        }
                    }
                }
            }
        }
        foreach (c; toRemove)
        {
            remove(c);
        }
        return this;
    }

    alias clippings this;
    /*size_t size() {
      return clippings.length;
      }
      auto keys() {
      return clippings.keys;
      }
    */
}

import std.regex;
import std.datetime;

int monthToNumber(string month)
{
    switch (month)
    {
    case "January":
        return 1;
    case "February":
        return 2;
    case "March":
        return 3;
    case "April":
        return 4;
    case "May":
        return 5;
    case "June":
        return 6;
    case "July":
        return 7;
    case "August":
        return 8;
    case "September":
        return 9;
    case "October":
        return 10;
    case "November":
        return 11;
    case "December":
        return 12;
    default:
        throw new Exception("Cannot convert month " ~ month);
    }
}

class Location
{
    int start;
    int end;
    this(int start)
    {
        this.start = start;
        this.end = -1;
    }

    this(int start, int end)
    {
        this.start = start;
        this.end = end;
    }

    bool intersects(Location l)
    {
        if (end == -1 && l.end == -1)
        {
            return start == l.start;
        }
        if (end == -1)
        {
            return start >= l.start && start <= l.end;
        }

        if (l.end == -1)
        {
            return start <= l.start && end >= l.end;
        }

        if (l.end < start)
        {
            return false;
        }

        if (end < l.start)
        {
            return false;
        }
        return true;
    }
}

class Clipping
{
    string book;
    string author;
    string type;
    Location location;
    string page;
    DateTime date;
    string content;
    size_t pos;
    Clipping[] childs;
    this(size_t pos, string book, string location, string content)
    {
        this.pos = pos;
        auto match = book.matchFirst(regex(`(.*)\((.*)\)`));
        this.book = match[1].rigorousStrip;
        this.author = match[2].rigorousStrip;
        auto typeMatch = location.matchFirst(regex(`.*Your Bookmark.*`));
        this.childs = [];
        if (typeMatch.length == 1)
        {
            this.type = "bookmark";
        }
        else
        {
            typeMatch = location.matchFirst(regex(`.*Your Highlight.*`));
            if (typeMatch.length == 1)
            {
                this.type = "highlight";
            }
            else
            {
                typeMatch = location.matchFirst(regex(`.*Your Note.*`));
                if (typeMatch.length == 1)
                {
                    this.type = "note";
                }
                else
                {
                    throw new Exception("Cannot find type in " ~ location);
                }
            }
        }

        auto locationMatch = location.matchFirst(regex(".*Location (\\d*)-(\\d*)"));
        if (locationMatch.length == 3)
        {
            this.location = new Location(locationMatch[1].to!int, locationMatch[2].to!int);
        }
        else
        {
            locationMatch = location.matchFirst(regex(".Location (\\d*)"));
            if (locationMatch.length == 2)
            {
                this.location = new Location(locationMatch[1].to!int);
            }
            else
            {
                throw new Exception("Cannot find location in " ~ location);
            }
        }

        auto pageMatch = location.matchFirst(regex(".*on page (\\d*)"));
        if (pageMatch.length == 2)
        {
            this.page = pageMatch[1];
        }
        else
        {
            this.page = "0";
        }

        auto dateMatch = location.matchFirst(regex(`.*Added on (?P<day>.*?), (?P<month>.*?) (?P<date>\d\d?), (?P<year>\d\d\d\d) (?P<h>\d\d?):(?P<m>\d\d):(?P<s>\d\d) (?P<ap>A|P)M`));
        alias toHour = (string h, string ap) => ap == "A" ? h.to!int
            : ((dateMatch["h"].to!int % 12) + 12);
        // writeln("Working on: " ~ location);
        if (dateMatch.length == 9)
        {
            this.date = DateTime(dateMatch["year"].to!int,
                    dateMatch["month"].monthToNumber, dateMatch["date"].to!int,
                    toHour(dateMatch["h"], dateMatch["ap"]),
                    dateMatch["m"].to!int, dateMatch["s"].to!int);
        }
        else
        {
            throw new Exception("Cannot find Added on in " ~ location);
        }
        this.content = content;
    }

    auto add(Clipping child)
    {
        childs ~= child;
        return this;
    }

    bool isHighlightOrNote()
    {
        return type == "highlight" || type == "note";
    }

    override string toString()
    {
        return "Book: " ~ book ~ "\n  Author: " ~ author ~ "\n  Page: " ~ page
            ~ "\n  Content: " ~ content ~ "\n";
    }
    /+
     string toKindle()
     {
     return book ~ "\r\n" ~ page ~ "\r\n\r\n" ~ content ~ "\r\n" ~ "==========" ~ "\r\n";
     }
     +/
}

string rigorousStrip(string s)
{
    auto res = s.strip;
    if (res.length > 3)
    {
        if (res[0 .. 3] == [0xef, 0xbb, 0xbf])
        {
            res = res[3 .. $];
        }
    }
    return res;
}

Clippings collect(Clippings clippings, string file)
{
    auto content = readText(file);
    auto lines = content.split("\r\n");
    writeln("Read ", lines.length, " lines");
    size_t pos = 0;
    if (lines.length % 5 != 1)
    {
        stderr.writeln("Cannot interprete clippings file");
        throw new Exception("Cannot interpret " ~ file);
    }

    while (lines.length >= 5)
    {
        auto clipping = new Clipping(pos, lines[0].rigorousStrip,
                lines[1].rigorousStrip, lines[3].rigorousStrip);
        if (clipping.isHighlightOrNote)
        {
            clippings.add(clipping);
        }
        lines = lines[5 .. $];
        pos += 5;
    }
    return clippings;
}

bool booksByNewestClipping(T)(T a, T b)
{
    auto clippings1 = a[1].array;
    auto clippings2 = b[1].array;

    return clippings1.map!("a.date.toISOString")
        .array.reduce!(min) > clippings2.map!("a.date.toISOString").array.reduce!(min);
}

bool byStartLocation(T)(T a, T b)
{
    return a.location.start < b.location.start;
}

string getTypeString(Clipping clipping)
{
    if (clipping.childs.length == 0)
    {
        return clipping.type.capitalize;
    }
    else
    {
        return clipping.type.capitalize ~ " with " ~ clipping.childs[0].type.capitalize;
    }
}

void writeHtml(T)(T allClippings)
{
    import std.file;

    /+auto byBook = allClippings.values.sort!("a.book < b.book").chunkBy!("a.book");
     +/
    string output = "<!DOCTYPE html>\n<html><head>";
    output ~= `  <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.2.1/css/bootstrap.min.css" integrity="sha384-GJzZqFGwb1QTTN6wy59ffF1BuGJpLSa9DkKMp0DgiMDm4iYMj70gZWKYbI706tWS" crossorigin="anonymous">` ~ "\n";
    //output ~= `  <link href="https://fonts.googleapis.com/css?family=Charm" rel="stylesheet">`;
    //output ~= `  <link href="https://fonts.googleapis.com/css?family=Dancing+Script" rel="stylesheet">`;
    output ~= `  <link href="https://fonts.googleapis.com/css?family=Kalam" rel="stylesheet">`;
    output ~= "\n  <style>\n";
    output ~= "    * { font-family: Optima; }\n";
    output ~= "    .toc { margin-left: 2em; width: 80%; }\n";
    output ~= "    .books { margin-left: 2em; width: 90%; }\n";
    output ~= "    .title { font-size: 2em; }\n";
    output ~= "    .author { font-style: italic; }\n";
    output ~= "    .count { font-style: italic; font-size: 0.8em;}\n";
    output ~= "    .page { font-style: italic; font-size: 0.8em;}\n";
    output ~= "    .date { font-style: italic; font-size: 0.8em; }\n";
    output ~= "    .clipping { margin-left: 2em; margin-right: 2em; display: block; page-break-inside: avoid; }\n";
    output ~= "    .book { display: block; page-break-before: always; }\n";
    output ~= "    .highlight { }\n";
    // output ~= "    .note { font-family: 'Charm', cursive; }\n";
    //output ~= "    .note { font-family: 'Dancing Script', cursive; }\n";
    output ~= "    .note { font-family: 'Kalam', cursive; }\n";
    output ~= "    .note { font-family: 'Dancing Script', cursive; }\n";
    output ~= "    .highlight .note { padding-left: 1em; border-left: 3px solid; }\n";
    output ~= "    ul { list-style-type: none; }\n";
    output ~= "  </style>\n";
    output ~= `</head><body><div class="books">`;
    auto byBook = allClippings.dup.values.sort!("a.book < b.book")
        .chunkBy!("a.book").array.sort!(booksByNewestClipping).array;
    int idx = 0;
    output ~= `<ul class="toc">`;
    foreach (book; byBook)
    {
        auto clippings = book[1].array;
        auto title = clippings[0].book;
        auto author = clippings[0].author;
        auto firstRead = clippings.map!("a.date.toISOString").array.reduce!(min);
        auto firstReadDate = DateTime.fromISOString(firstRead);
        output ~= `  <li><a href="#%d">%s, %s-%02d</a></li>`.format(idx, title,
                firstReadDate.year, firstReadDate.month.to!int);
        idx++;
    }
    output ~= "</ul>";
    idx = 0;
    output ~= `<div class="books">`;
    foreach (book; byBook.array)
    {
        auto clippings = book[1].array;
        auto title = clippings[0].book;
        auto author = clippings[0].author;

        output ~= `<a class="book" name="%s" />`.format(idx);
        output ~= `<span class="title">%s</span>`.format(title) ~ "\n";
        output ~= `<span class="author"> by %s</span>`.format(author) ~ "\n";
        auto highlights = clippings.filter!(`a.type == "highlight"`).count;
        auto notes = clippings.filter!(
                `a.type =="note" || a.childs.filter!(a => a.type == "note").count`).count;

        output ~= "</br>\n";
        if (highlights != 0)
        {
            output ~= `<span class="count">%s Highlights</span>`.format(highlights);
            if (notes != 0)
            {
                output ~= `<span class="count"> - %s Notes</span>`.format(notes);
            }
        }
        else
        {
            if (notes != 0)
            {
                output ~= `<span class="count">%s Notes</span>`.format(notes);
            }
        }
        output ~= "\n";
        output ~= "<hr/>";
        foreach (clipping; clippings.sort!byStartLocation)
        {
            output ~= `<span class="clipping">`;
            if (clipping.page != "0")
            {
                output ~= "    <span class=\"page\">Page " ~ clipping.page ~ "</span>";
            }
            output ~= `    <span class="date">%s</span>`.format(
                    clipping.date.to!string[0 .. $ - 3]) ~ "\n";
            output ~= " - " ~ `<span class="date">%s</span></br>`.format(
                    clipping.getTypeString) ~ "\n";
            output ~= "    <div class=\"%s\">%s\n".format(clipping.type, clipping.content);
            foreach (note; clipping.childs)
            {
                output ~= `      <p class="note">%s</p>`.format(note.content);
            }
            output ~= "    </div>\n";
            output ~= "<hr/>";
            output ~= `</span>`;
        }
        idx++;
    }
    output ~= "</div></body></html>";
    std.file.write("out/all.html", output);
}

int main(string[] args)
{
    args.writeln;

    Clippings allClippings = new Clippings;

    if (args.length < 2)
    {
        "Usage: clippings filename".writeln;
        return 1;
    }
    foreach (file; args[1 .. $])
    {
        allClippings.collect(file);
    }
    stderr.writeln(allClippings.length, " clippings in total");

    allClippings.assignNotesToClippings;
    allClippings.writeHtml;
    return 0;
}
