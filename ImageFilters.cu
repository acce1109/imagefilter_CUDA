#include <iostream>
#include "cuda.h"
#include "cuda_runtime.h"
#include "device_launch_parameters.h"
#include <stdio.h>
#include <windows.h>


using namespace std;

BITMAPFILEHEADER bitfilehead; // 14 bajtowy nag³ówek pliku bitmapy,/ Zawiera informacje o parametrach pliku BMP
BITMAPINFOHEADER bitinfohead; // Zawiera informacje na temat wymiarów i kolorów w formacie DIB,/ Zawiera informacje o parametrach bitmapy.

// Wczytywanie nag³ówka pliku
void OpenImage()
{
	char *filename = "lena.bmp";
	FILE *input = fopen(filename, "rb+");

	if (input == NULL)
	{
		printf("- Plik nie zostal otwarty (Wczytywanie naglowka pliku)\n");
		exit(0);
	}
	printf("- Plik zostal otwarty pomyslnie (Wczytywanie naglowka pliku)\n");

	if (fread(&bitfilehead, sizeof(BITMAPFILEHEADER), 1, input) != 1) {
		printf(" Blad w odczycie naglowka bmp\n");
	}

	if (fread(&bitinfohead, sizeof(BITMAPINFOHEADER), 1, input) != 1) {
		printf(" Blad w odczycie informacji o zdjeciu\n");
	}
	fclose(input);

}


__global__ void GPUlowFilter(unsigned char* buffer, unsigned char* result, int width, int height)
{
	int col = threadIdx.x;
	int row = blockIdx.x * width * 3;
	const int maskSize = 7;
	int maskSizeHalf = (maskSize - 1) / 2;
	if (blockIdx.x >= height - maskSize-2)

		return;
	//Maska 5x5 Filtr dolnoprzepustowy
	/*int mask[maskSize][maskSize] = { 1, 1, 1, 1, 1,
									   1, 1, 1, 1, 1,
									   1, 1, 1, 1, 1,
									   1, 1, 1, 1, 1,
									   1, 1, 1, 1, 1 };*/
	int mask[maskSize][maskSize] = { 1, 1, 2, 2 , 2, 1, 1,
									 1, 2, 2, 4 , 2, 2, 1,
									 2, 2, 4, 8 , 4, 2, 2,
									 2, 4, 8, 16, 8, 4, 2,
									 2, 2, 4, 8 , 4, 2, 2,
									 1, 2, 2, 4 , 2, 2, 1,
									 1, 1, 2, 2 , 2, 1, 1,};
	//Maska 17x17 Filtr dolnoprzepustowy
	 /*int mask[maskSize][maskSize] =	   {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
										1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,};*/

	//Suma wszystkich argumentow maski
	// int devider = 289; //dla 17x17
	int devider = 120;
	for (int c = 0; c < 3; c++){
		
		if (c == 3 && col >= width - maskSize-2){
			return;
		}
	
		for (int channel = 0; channel < 3; channel++){
			float sum = 0.0;
			for (int j = -maskSizeHalf; j <= maskSizeHalf; j++){

				for (int i = -maskSizeHalf; i <= maskSizeHalf; i++){

					int rowN = (blockIdx.x + j) * width * 3;
					int  color = buffer[(rowN)+(col + i) + width*c + channel];//channel0
					sum += color * mask[i + maskSizeHalf][j + maskSizeHalf];
				}
			}
			result[(row + col) + width*c+channel] = (char)(sum / devider);
		}
	}
}
__global__ void GPUhightFilter(unsigned char* buffer, unsigned char* result, int width, int height)
{
	int col = threadIdx.x;
	int row = blockIdx.x * width * 3;
	const int maskSize = 3;
	int maskSizeHalf = (maskSize - 1) / 2;
	if (blockIdx.x >= height - maskSize - 2)

	return;
	//Maska 3x3 Filtr gornoprzepustowy
	int mask[maskSize][maskSize] = {  1, -2,  1,
									 -2,  5, -2,
								      1, -2,  1, };
	//Maska 5x5 Filtr gornoprzepustowy
	/*int mask[maskSize][maskSize] = { -1, -1, -1, -1, -1,
									 -1, -1, -1, -1, -1,
									 -1, -1, 24, -1, -1,
									 -1, -1, -1, -1, -1,
									 -1, -1, -1, -1, -1 };*/

	//Maska 7x7 Filtr gornoprzepustowy
	/*int mask[maskSize][maskSize] = { -1, -1, -1, -1, -1, -1, -1, 
									 -1, -1, -1, -1, -1, -1, -1, 
									 -1, -1, -1, -1, -1, -1, -1, 
									 -1, -1, -1, 48, -1, -1, -1, 
									 -1, -1, -1, -1, -1, -1, -1, 
									 -1, -1, -1, -1, -1, -1, -1, 
									 -1, -1, -1, -1, -1, -1, -1,};*/

	//Suma wszystkich argumentow maski
	int devider = 1;

	for (int c = 0; c < 3; c++){

		if (c == 3 && col >= width - maskSize - 2){
			return;
		}

		for (int channel = 0; channel < 3; channel++){
			float sum = 0.0;
			for (int j = -maskSizeHalf; j <= maskSizeHalf; j++){

				for (int i = -maskSizeHalf; i <= maskSizeHalf; i++){

					int rowN = (blockIdx.x + j) * width * 3;
					int  color = buffer[(rowN)+(col + i) + width*c + channel];//channel0
					sum += color * mask[i + maskSizeHalf][j + maskSizeHalf];
				}
			}
			result[(row + col) + width*c + channel] = (char)(sum / devider);
		}
	}
}



int main()
{
	
	int start = GetTickCount(); // Pobiera aktualny czas

	OpenImage();



	int channels = bitinfohead.biBitCount/ 8;

	unsigned long int n = bitinfohead.biWidth*bitinfohead.biHeight * channels;
	
	
	unsigned char *buffer_cuda;
	unsigned char *result_cuda;
	
	
	cudaMalloc((void**)&buffer_cuda, bitinfohead.biWidth*bitinfohead.biHeight * channels * sizeof(unsigned char));
	cudaMalloc((void**)&result_cuda, bitinfohead.biWidth*bitinfohead.biHeight * channels * sizeof(unsigned char));
	
	unsigned char *buffer = (unsigned char*)malloc(bitinfohead.biWidth*bitinfohead.biHeight * channels);
	unsigned char *result = (unsigned char*)malloc(bitinfohead.biWidth*bitinfohead.biHeight * channels);
	
	//Czytanie danych z pliku i tworzenie chara z danymi zdjêcia
	char *filename = "lena.bmp";
	FILE *input = fopen(filename, "rb+");

	fseek(input, bitfilehead.bfOffBits, SEEK_SET);

	for (int i = 0; i < n; i++)
	{
		buffer[i] = fgetc(input);
	}
	printf("- Odczytano pomyslnie zawartosc danych o obrazie i zapisano do tablicy na CPU\n");
	fclose(input);

	cudaMemcpy(buffer_cuda, buffer, bitinfohead.biWidth*bitinfohead.biHeight * channels * sizeof(unsigned char), cudaMemcpyHostToDevice);
	
	int choice;
	cout << "Filtr" << endl;
	cout << " LowPass Filter [1] " << endl;
	cout << " HightPass Filter [2] " << endl;
	cin >> choice;
	switch (choice)
	{
	case 1: {
				

				GPUlowFilter << <512, 512 >> > (buffer_cuda, result_cuda, bitinfohead.biWidth, bitinfohead.biHeight * 3);
				
	}
		break;
	case 2: 

				GPUhightFilter << <512, 512 >> > (buffer_cuda, result_cuda, bitinfohead.biWidth, bitinfohead.biHeight * 3);
		break;
	}
	


	cudaMemcpy(result, result_cuda, bitinfohead.biWidth*bitinfohead.biHeight * channels, cudaMemcpyDeviceToHost);
	
	//Zapisywanie wyjœciowych danych z kernela jako plik bmp
	char *plik = "projekt_output.bmp";
	FILE *output = fopen(plik, "wb+");

	if (output == NULL)
	{
		printf("- Plik nie zostal otwarty (Zapisywanie bitmapy do pliku)\n");
		exit(0);
	}
	printf("- Plik zostal otwarty pomyslnie (Zapisywanie bitmapy do pliku)\n");

	// Zapis nag³ówka
	fwrite(&bitfilehead, 1, sizeof(bitfilehead), output);
	// Zapis informacji o pliku
	fwrite(&bitinfohead, sizeof(bitinfohead), 1, output);
	// Zapisuje dane obrazu
	fwrite(result, sizeof(unsigned char), bitinfohead.biWidth*bitinfohead.biHeight * channels, output);

	fclose(output);


	cudaFree(buffer_cuda);
	cudaFree(result_cuda);
	free(result);
	free(buffer);

	cout << "Czas wykonania kodu aplikacji: " << GetTickCount() - start << "ms." << endl;
	system("pause");
	return 0;
}
