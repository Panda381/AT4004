// Export BIN file to C source file

#include <stdio.h>
#include <malloc.h>

#pragma warning(disable : 4996)

int main(int argc, char* argv[])
{
	// check syntax
	if (argc != 4)
	{
		printf("Use syntax: BinC infile.bin outfile.c tablename\n");
		return 1;
	}

	// open input file
	FILE* f = fopen(argv[1], "rb");
	if (f == NULL)
	{
		printf("Cannot open input file %s\n", argv[1]);
		return 2;
	}

	// get size of input file
	fseek(f, 0, SEEK_END);
	size_t size = ftell(f);
	fseek(f, 0, SEEK_SET);

	// allocate buffer
	unsigned char* buf = (unsigned char*)malloc(size);
	if (buf == NULL)
	{
		printf("Input file size or memory error\n");
		return 3;
	}
		 
	// read file
	if (fread(buf, 1, size, f) != size)
	{
		printf("Read error\n");
		return 4;
	}
	fclose(f);

	// open output file
	f = fopen(argv[2], "wb");
	if (f == NULL)
	{
		printf("Cannot create output file %s\n", argv[2]);
		return 5;
	}

	// print table head
	fprintf(f, "#include \"include.h\"\n\n");
	fprintf(f, "const u8 %s[%u] PROGMEM = {\n\t", argv[3], size);

	// export file
	int pos = 0;
	int i;
	for (i = 0; i < (int)size; i++)
	{
		pos++;
		if ((pos == 16) && (i < (int)size-1))
		{
			fprintf(f, "0x%02x,\n\t", buf[i]);
			pos = 0;
		}
		else
			fprintf(f, "0x%02x, ", buf[i]);
	}

	// print end
	fprintf(f, "\n};\n");

	// close output file
	fclose(f);

	return 0;
}

