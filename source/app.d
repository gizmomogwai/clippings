import std.stdio;
import std.file;
import std.algorithm;
import std.range;
import std.string;
import std.conv;

class Clippings
{
    Clipping[string] clippings;
    Clippings add(Clipping clipping)
    {
        string h = clipping.toString;
        if (h !in clippings)
        {
            clippings[h] = clipping;
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

class Clipping
{
    string book;
    string author;
    string type;
    int startLocation;
    string page;
    string date;
    string content;
    size_t pos;
    this(size_t pos, string book, string location, string content)
    {
        this.pos = pos;
        auto match = book.matchFirst(regex(`(.*)\((.*)\)`));
        this.book = match[1].rigorousStrip;
        this.author = match[2].rigorousStrip;
        auto typeMatch = location.matchFirst(regex(`.*Your Bookmark.*`));
        if (typeMatch.length == 1) {
            this.type = "Bookmark";
        } else {
            typeMatch = location.matchFirst(regex(`.*Your Highlight.*`));
            if (typeMatch.length == 1) {
                this.type = "Highlight";
            } else {
                throw new Exception("Cannot find type in " ~ location);
            }
        }

        auto locationMatch = location.matchFirst(regex(".*Location (\\d*)"));
        if (locationMatch.length == 2) {
            this.startLocation = locationMatch[1].to!int;
        } else {
            throw new Exception("Cannot find location in " ~ location);
        }

        auto pageMatch = location.matchFirst(regex(".*on page (\\d*)"));
        if (pageMatch.length == 2) {
            this.page = pageMatch[1];
        } else {
            this.page = "0";
        }

        auto dateMatch = location.matchFirst(regex(".*Added on (.*)"));
        if (dateMatch.length == 2) {
            this.date = dateMatch[1];
        } else {
            throw new Exception("Cannot find Added on in " ~ location);
        }
        this.content = content;
    }

    bool isHighlight() {
        return type == "Highlight";
    }
    
    override string toString()
    {
        return "Book: " ~ book ~ "\n  Author: " ~ author ~ "\n  Page: "
            ~ page ~ "\n  Content: " ~ content ~ "\n";
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
        if (clipping.isHighlight) {
            clippings.add(clipping);
        }
        lines = lines[5 .. $];
        pos += 5;
    }
    return clippings;
}

void writeHtml(T)(T clippings)
{
    import std.file;

    auto title = clippings[0].book;
    auto author = clippings[0].author;
    
    string output = "<!DOCTYPE html>\n<html><head>";
    output ~= `  <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.2.1/css/bootstrap.min.css" integrity="sha384-GJzZqFGwb1QTTN6wy59ffF1BuGJpLSa9DkKMp0DgiMDm4iYMj70gZWKYbI706tWS" crossorigin="anonymous">` ~ "\n";
    output ~= "  <style>\n";
    output ~= "    .title { font-size: 2em; }\n";
    output ~= "    .author { font-style: italic; }\n";
    output ~= "    .date { font-style: italic; font-size: 0.8em; }\n";
    output ~= "    .clipping { display: block; page-break-inside: avoid; }\n";
    output ~= "  </style>\n";
    output ~= "</head><body>";
    output ~= `<span class="title">` ~ title~ "</span>\n" ~ `<span class="author"> by ` ~ author ~ "</span>\n";
    output ~= "<p>" ~ clippings.length.to!string ~ " Highlights</p>";
    output ~= "<hr/>";
                                                       foreach (clipping; clippings.sort!"a.startLocation < b.startLocation")
                                                       {
                                                           output ~= `<span class="clipping">`;
                                                           if (clipping.page != "0") {
                                                               output ~= "    <span class=\"page\">Page " ~ clipping.page ~ "</span>";
                                                           }
                                                           output ~= "    <span class=\"date\"> on " ~ clipping.date ~ "</span><br/>\n";
                                                           output ~= "    <q class=\"content\">" ~ clipping.content ~ "</q>\n";
                                                           output ~= "<hr/>";
                                                           output ~= `</span>`;
                                                       }
                                                       output ~= "</body></html>";

    std.file.write("out/" ~ title ~ ".html", output);
}

int main(string[] args)
{
    args.writeln;

    Clippings allClippings = new Clippings;

    foreach (file; args[1 .. $])
    {
        allClippings.collect(file);
    }
    /+
     auto output = File("out.txt", "w");
     foreach (key; allClippings.keys.sort)
     {
     output.write(allClippings[key].toKindle);
     }
     +/
    stderr.writeln(allClippings.length, " clippings in total");

    import asciitable;

    auto table = new AsciiTable(2);

    auto byBook = allClippings.values.sort!("a.book < b.book").chunkBy!("a.book");
    foreach (bookClippings; byBook)
    {
        auto name = bookClippings[0].rigorousStrip;

        auto clippings = bookClippings[1].array;
        table.row().add(name ~ ", " ~ clippings[0].author).add(clippings.length.to!string);
        foreach (clipping; clippings)
        {
            //            table.row().add(" - ").add(clipping.pos.to!string);
        }

        writeHtml(clippings);
    }
    table.format.prefix("  | ").writeln;

    return 0;
}
