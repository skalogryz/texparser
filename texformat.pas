unit texformat;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  // https://ctan.org/topic/class
  DocCls_article  = 'article';	// For articles in scientific journals, presentations, short reports, program documentation, invitations, ...
  DocCls_IEEEtran = 'IEEEtran';	// For articles with the IEEE Transactions format.
  DocCls_proc     = 'proc';	// A class for proceedings based on the article class.
  DocCls_minimal  = 'minimal';	// It is as small as it can get. It only sets a page size and a base font. It is mainly used for debugging purposes.
  DocCls_report   = 'report';	// For longer reports containing several chapters, small books, thesis, ...
  DocCls_book     = 'book';	// For books.
  DocCls_slides   = 'slides';	// For slides. The class uses big sans serif letters.
  DocCls_memoir   = 'memoir';	// For sensibly changing the output of the document. It is based on the book class, but you can create any kind of document with it [1]
  DocCls_letter   = 'letter';	// For writing letters.
  DocCls_beamer   = 'beamer';   // For writing presentations (see LaTeX/Presentations).

implementation

end.

