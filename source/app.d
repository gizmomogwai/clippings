import std.stdio;
import std.file;
import std.algorithm;
import std.range;

class Clippings {
  Clipping[string] clippings;
  Clippings add(Clipping clipping) {
    string h = clipping.toString;
    if (h !in clippings) {
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

class Clipping {
  string book;
  string location;
  string content;
  this(string book, string location, string content) {
    this.book = book;
    this.location = location;
    this.content = content;
  }
  override string toString() {
    return "Book: " ~ book ~ "\n  Location: " ~ location ~ "\n  Content: " ~ content;
  }
  string toKindle() {
    return book ~ "\r\n" ~ location ~ "\r\n\r\n" ~ content ~ "\r\n" ~ "==========" ~ "\r\n";
  }
}
Clippings collect(Clippings clippings, string file) {
  auto content = readText(file);
  auto lines = content.split("\r\n");
  writeln("Read ", lines.length, " lines");
  if (lines.length % 5 != 1) {
    stderr.writeln("Cannot interprete clippings file");
    throw new Exception("Cannot interpret " ~ file);
  }

  while (lines.length >= 5) {
    auto clipping = new Clipping(lines[0], lines[1], lines[3]);
    clippings.add(clipping);
    lines = lines[5..$];
  }
  return clippings;
}

int main(string[] args)
{
  args.writeln;

  Clippings allClippings = new Clippings;

  foreach (file; args[1..$]) {
    allClippings.collect(file);
  }

  auto output = File("out.txt", "w");
  foreach (key; allClippings.keys.sort) {
    output.write(allClippings[key].toKindle);
  }
  stderr.writeln(allClippings.length, " clippings in total");


  
  return 0;
}
